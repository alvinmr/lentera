import Foundation
import os

// Bundle.module is generated main-actor-isolated under default actor isolation,
// so resolve the SwiftPM resource bundle from the executable's resources instead.
private nonisolated let resourceBundle =
  Bundle.main.url(forResource: "Lentera_Lentera", withExtension: "bundle")
  .flatMap(Bundle.init(url:)) ?? .main

nonisolated struct ProgressUpdate: Sendable {
  let progress: Double
  let message: String
}

nonisolated enum ConversionError: LocalizedError {
  case missingTool(String)
  case invalidInput
  case commandFailed(String, String)
  case outputMissing
  case calibreRequired

  var errorDescription: String? {
    switch self {
    case .missingTool(let name):
      return
        "The \(name) engine is not available. Run Scripts/build-engine.sh and rebuild the app."
    case .invalidInput:
      return "The ACSM file is invalid or cannot be read."
    case .commandFailed(let command, let output):
      return FriendlyError.message(command: command, output: output)
    case .outputMissing:
      return "The download finished, but the book file was not found."
    case .calibreRequired:
      return
        "The book is available in a different format. Install Calibre to convert between EPUB and PDF, then try again."
    }
  }
}

nonisolated struct ConversionService: Sendable {
  @concurrent func convert(
    acsm: URL,
    destination: URL,
    progress: @escaping @Sendable (ProgressUpdate) -> Void
  ) async throws -> ConversionResult {
    guard acsm.isFileURL, FileManager.default.isReadableFile(atPath: acsm.path) else {
      throw ConversionError.invalidInput
    }

    let tools = try ToolLocator.resolve()
    let work = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: work) }

    let adept = try persistentAdeptDirectory()
    if !FileManager.default.fileExists(atPath: adept.appendingPathComponent("activation.xml").path) {
      progress(.init(progress: 0.12, message: "Activating Adobe device…"))
      _ = try await run(
        tools.activate, ["--anonymous", "--random-serial", "--output-dir", adept.path],
        currentDirectory: work)
    }

    try Task.checkCancellation()
    progress(.init(progress: 0.32, message: "Downloading the book from the provider…"))
    let downloadOutput = try await run(
      tools.downloader,
      ["--adept-directory", adept.path, acsm.path],
      currentDirectory: work
    )

    let encrypted = try downloadedBook(in: work, commandOutput: downloadOutput)
    let nativeExtension = encrypted.pathExtension.lowercased()
    guard let format = OutputFormat(rawValue: nativeExtension.uppercased()) else {
      throw ConversionError.outputMissing
    }
    let decrypted = work.appendingPathComponent("decrypted.\(nativeExtension)")

    try Task.checkCancellation()
    progress(.init(progress: 0.68, message: "Removing book protection…"))
    _ = try await run(
      tools.remove,
      ["--adept-directory", adept.path, "--output-file", decrypted.path, encrypted.path],
      currentDirectory: work
    )

    let metadata = await BookMetadata.read(from: decrypted, fallbackTitle: encrypted.deletingPathExtension().lastPathComponent)

    try Task.checkCancellation()
    progress(.init(progress: 0.96, message: "Saving…"))
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    let finalURL = uniqueDestination(
      directory: destination,
      baseName: safeBaseName(metadata.title),
      extension: format.fileExtension
    )
    try FileManager.default.copyItem(at: decrypted, to: finalURL)
    progress(.init(progress: 1, message: "Done"))
    return ConversionResult(
      fileURL: finalURL,
      title: metadata.title,
      author: metadata.author,
      format: format,
      coverData: metadata.coverData
    )
  }

  private func persistentAdeptDirectory() throws -> URL {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Lentera", isDirectory: true)
    try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
    let adept = support.appendingPathComponent("adept", isDirectory: true)
    try FileManager.default.createDirectory(at: adept, withIntermediateDirectories: true)
    return adept
  }

  private func downloadedBook(in directory: URL, commandOutput: String) throws -> URL {
    let files = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    )
    if let result = files.first(where: { ["epub", "pdf"].contains($0.pathExtension.lowercased()) })
    {
      return result
    }
    throw ConversionError.commandFailed("acsmdownloader", commandOutput)
  }

  @concurrent func run(_ executable: URL, _ arguments: [String], currentDirectory: URL) async throws
    -> String
  {
    try Task.checkCancellation()
    let handle = RunningProcess()
    do {
      let output = try await withTaskCancellationHandler {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.standardOutput = pipe
        process.standardError = pipe
        defer { handle.clear() }
        try handle.start(process)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
          throw ConversionError.commandFailed(executable.lastPathComponent, output)
        }
        return output
      } onCancel: {
        handle.terminate()
      }
      try Task.checkCancellation()
      return output
    } catch {
      try Task.checkCancellation()
      throw error
    }
  }

  func safeBaseName(_ name: String) -> String {
    let invalid = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\:"))
    let cleaned = name.components(separatedBy: invalid).joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
    return String(cleaned.prefix(120)).isEmpty ? "Book" : String(cleaned.prefix(120))
  }

  func uniqueDestination(directory: URL, baseName: String, extension ext: String) -> URL {
    var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(ext)
    var suffix = 2
    while FileManager.default.fileExists(atPath: candidate.path) {
      candidate = directory.appendingPathComponent("\(baseName) \(suffix)").appendingPathExtension(
        ext)
      suffix += 1
    }
    return candidate
  }
}

private nonisolated final class RunningProcess: @unchecked Sendable {
  private struct State {
    var process: Process?
    var terminationRequested = false
  }

  // Start and cancellation share a lock so terminate never precedes launch.
  private let state = OSAllocatedUnfairLock(initialState: State())

  func start(_ process: Process) throws {
    try state.withLock { state in
      guard !state.terminationRequested else { throw CancellationError() }
      try process.run()
      state.process = process
    }
  }

  func clear() {
    state.withLock { $0.process = nil }
  }

  func terminate() {
    state.withLock { state in
      state.terminationRequested = true
      if let process = state.process, process.isRunning { process.terminate() }
    }
  }
}

nonisolated struct ToolLocator {
  let activate: URL
  let downloader: URL
  let remove: URL

  static func resolve() throws -> ToolLocator {
    ToolLocator(
      activate: try tool("adept_activate"),
      downloader: try tool("acsmdownloader"),
      remove: try tool("adept_remove")
    )
  }

  private static func tool(_ name: String) throws -> URL {
    let bundled = resourceBundle.url(forResource: name, withExtension: nil)
    if let bundled, FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
    guard let external = firstExisting(["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"])
    else {
      throw ConversionError.missingTool(name)
    }
    return external
  }

  private static func firstExisting(_ paths: [String]) -> URL? {
    paths.lazy.map(URL.init(fileURLWithPath:)).first {
      FileManager.default.isExecutableFile(atPath: $0.path)
    }
  }
}

nonisolated struct BookMetadata: Sendable {
  let title: String
  let author: String
  let coverData: Data?

  @concurrent static func read(from file: URL, fallbackTitle: String) async -> BookMetadata {
    guard file.pathExtension.lowercased() == "epub" else {
      return BookMetadata(title: fallbackTitle, author: "Author unavailable", coverData: nil)
    }

    guard let container = xml(unzipData(file, entry: "META-INF/container.xml")),
      let packagePath = value(container, "//*[local-name()='rootfile']/@full-path"),
      let package = xml(unzipData(file, entry: packagePath))
    else { return BookMetadata(title: fallbackTitle, author: "Author unavailable", coverData: nil) }

    let title = value(package, "//*[local-name()='metadata']/*[local-name()='title']") ?? fallbackTitle
    let author = value(package, "//*[local-name()='metadata']/*[local-name()='creator']") ?? "Author unavailable"
    let coverID = value(package, "//*[local-name()='meta'][@name='cover']/@content")
    let items = (try? package.nodes(forXPath: "//*[local-name()='manifest']/*[local-name()='item']")) ?? []
    let elements = items.compactMap { $0 as? XMLElement }
    let cover = elements.first {
      ($0.attribute(forName: "properties")?.stringValue ?? "").split(whereSeparator: { $0.isWhitespace }).contains("cover-image")
    } ?? elements.first {
      guard let coverID else { return false }
      return $0.attribute(forName: "id")?.stringValue == coverID
    }
    let coverData: Data?
    if let href = cover?.attribute(forName: "href")?.stringValue,
      let base = URL(string: "https://epub.invalid/" + packagePath),
      let resolved = URL(string: href, relativeTo: base)?.absoluteURL,
      resolved.scheme == "https", resolved.host == "epub.invalid"
    {
      coverData = unzipData(file, entry: String(resolved.path.dropFirst()))
    } else {
      coverData = nil
    }
    return BookMetadata(title: title, author: author, coverData: coverData)
  }

  private static func xml(_ data: Data?) -> XMLDocument? {
    guard let data else { return nil }
    return try? XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])
  }

  private static func value(_ document: XMLDocument, _ path: String) -> String? {
    guard let node = try? document.nodes(forXPath: path).first,
      let value = node.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
    else { return nil }
    return value
  }

  private static func unzipData(_ file: URL, entry: String) -> Data? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-p", file.path, entry]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return process.terminationStatus == 0 && !data.isEmpty ? data : nil
  }


}

nonisolated enum FriendlyError {
  static func message(command: String, output: String) -> String {
    let messages = [
      "E_LIC_ALREADY_FULFILLED_BY_ANOTHER_USER":
        "This ACSM was already opened with another device or account. Download a new ACSM from the provider, or use the same authorization.",
      "E_GOOGLE_DEVICE_LIMIT_REACHED":
        "The Google Play device limit has been reached. Remove an old device authorization or contact Google support.",
      "E_ADEPT_REQUEST_EXPIRED":
        "This ACSM file has expired. Download a fresh ACSM copy from the book provider.",
      "E_LIC_LICENSE_SIGN_ERROR":
        "The book provider failed to sign the license. Wait a few minutes and try again.",
      "HTTP Error code 429":
        "The book provider is rate limiting requests. Wait 5–15 minutes and try again.",
    ]
    if let match = messages.first(where: { output.contains($0.key) }) { return match.value }
    let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
    return detail.isEmpty
      ? "\(command) failed without further details."
      : "\(command) failed. Open the technical details to see the full output."
  }
}
