import Foundation

/// The Adobe device activation that libgourou keeps in Application Support.
/// Moving it to another Mac lets that Mac open books licensed to this device.
nonisolated enum AdobeActivation {
  static let requiredFiles = ["activation.xml", "device.xml", "devicesalt"]

  enum Account: Equatable, Sendable {
    case anonymous
    case adobeID(String)
  }

  enum ActivationError: LocalizedError {
    case notActivated
    case invalidBackup
    case commandFailed(String)

    var errorDescription: String? {
      switch self {
      case .notActivated:
        "This Mac has no Adobe activation yet. Convert a book first, then export."
      case .invalidBackup:
        "The selection is not a Lentera activation backup. It must contain activation.xml, device.xml, and devicesalt."
      case .commandFailed(let output):
        "The archive could not be processed. \(output)"
      }
    }
  }

  static var directory: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Lentera/adept", isDirectory: true)
  }

  static func isActivated(in directory: URL = directory) -> Bool {
    requiredFiles.allSatisfy {
      FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
    }
  }

  static func account(in directory: URL = directory) -> Account? {
    let file = directory.appendingPathComponent("activation.xml")
    guard let document = try? XMLDocument(contentsOf: file, options: [.nodeLoadExternalEntitiesNever]),
      let node = try? document.nodes(forXPath: "//*[local-name()='username']").first as? XMLElement
    else { return nil }
    let method = node.attribute(forName: "method")?.stringValue ?? ""
    let name = node.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return method.lowercased() == "anonymous" || name.isEmpty ? .anonymous : .adobeID(name)
  }

  static func activationDate(in directory: URL = directory) -> Date? {
    let file = directory.appendingPathComponent("activation.xml")
    return try? file.resourceValues(forKeys: [.creationDateKey]).creationDate
  }

  /// Writes the activation files to a ZIP archive.
  @concurrent static func export(from directory: URL = directory, to archive: URL) async throws {
    guard isActivated(in: directory) else { throw ActivationError.notActivated }
    let staging = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let folder = staging.appendingPathComponent("Lentera Activation", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: staging) }
    for name in requiredFiles {
      try FileManager.default.copyItem(
        at: directory.appendingPathComponent(name), to: folder.appendingPathComponent(name))
    }
    try? FileManager.default.removeItem(at: archive)
    try ditto(["-c", "-k", "--keepParent", folder.path, archive.path])
  }

  /// Replaces the current activation with one from a ZIP archive or a folder.
  /// The previous activation goes to the Trash, so the change can be undone.
  @concurrent static func importBackup(from source: URL, into directory: URL = directory)
    async throws
  {
    let staging = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: staging) }

    let root: URL
    if (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
      root = source
    } else {
      try ditto(["-x", "-k", source.path, staging.path])
      root = staging
    }
    guard let found = activationFolder(in: root),
      (try? XMLDocument(
        contentsOf: found.appendingPathComponent("activation.xml"),
        options: [.nodeLoadExternalEntitiesNever])) != nil
    else { throw ActivationError.invalidBackup }
    guard found.resolvingSymlinksInPath().standardizedFileURL.path
      != directory.resolvingSymlinksInPath().standardizedFileURL.path
    else { return }

    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: directory.path) {
      try fileManager.trashItem(at: directory, resultingItemURL: nil)
    }
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    for name in requiredFiles {
      try fileManager.copyItem(
        at: found.appendingPathComponent(name), to: directory.appendingPathComponent(name))
    }
  }

  /// Moves the activation to the Trash. The next conversion activates a new device.
  static func reset(directory: URL = directory) throws {
    guard FileManager.default.fileExists(atPath: directory.path) else { return }
    try FileManager.default.trashItem(at: directory, resultingItemURL: nil)
  }

  private static func activationFolder(in root: URL) -> URL? {
    if isActivated(in: root) { return root }
    // libgourou's own tools keep the activation in a hidden `.adept` folder.
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
    while let file = files?.nextObject() as? URL {
      if file.lastPathComponent == "activation.xml",
        isActivated(in: file.deletingLastPathComponent())
      {
        return file.deletingLastPathComponent()
      }
    }
    return nil
  }

  private static func ditto(_ arguments: [String]) throws {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw ActivationError.commandFailed(String(decoding: output, as: UTF8.self))
    }
  }
}
