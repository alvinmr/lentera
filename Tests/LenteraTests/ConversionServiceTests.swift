import Foundation
import Testing

@testable import Lentera

private func makeTools(in directory: URL, downloader: String) throws -> ToolLocator {
  let activate = directory.appendingPathComponent("adept_activate")
  let downloaderURL = directory.appendingPathComponent("acsmdownloader")
  let remove = directory.appendingPathComponent("adept_remove")
  try "#!/bin/sh\nmkdir -p \"$4\"\ntouch \"$4/activation.xml\"\n".write(
    to: activate, atomically: true, encoding: .utf8)
  try downloader.write(to: downloaderURL, atomically: true, encoding: .utf8)
  try "#!/bin/sh\ncp \"$5\" \"$4\"\n".write(to: remove, atomically: true, encoding: .utf8)
  for url in [activate, downloaderURL, remove] {
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
  }
  return ToolLocator(activate: activate, downloader: downloaderURL, remove: remove)
}

private func makeWorkspace() throws -> (root: URL, tools: URL, adept: URL, destination: URL) {
  let fileManager = FileManager.default
  let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let tools = root.appendingPathComponent("tools")
  let adept = root.appendingPathComponent("adept")
  let destination = root.appendingPathComponent("out")
  for directory in [tools, adept, destination] {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  }
  return (root, tools, adept, destination)
}

@Test func conversionPipelineRunsProvidedTools() async throws {
  let fileManager = FileManager.default
  let workspace = try makeWorkspace()
  defer { try? fileManager.removeItem(at: workspace.root) }
  let tools = try makeTools(
    in: workspace.tools,
    downloader: "#!/bin/sh\nprintf 'fake-epub' > \"$PWD/downloaded.epub\"\n")
  let acsm = workspace.root.appendingPathComponent("book.acsm")
  try Data("acsm".utf8).write(to: acsm)

  let result = try await ConversionService(tools: tools, adeptDirectory: workspace.adept).convert(
    acsm: acsm, destination: workspace.destination
  ) { _ in }

  #expect(result.format == .epub)
  #expect(result.fileURL.lastPathComponent == "downloaded.epub")
  #expect(fileManager.fileExists(atPath: result.fileURL.path))
}

@Test func conversionReportsFailingTool() async throws {
  let fileManager = FileManager.default
  let workspace = try makeWorkspace()
  defer { try? fileManager.removeItem(at: workspace.root) }
  let tools = try makeTools(
    in: workspace.tools,
    downloader: "#!/bin/sh\necho 'boom' >&2\nexit 7\n")
  let acsm = workspace.root.appendingPathComponent("book.acsm")
  try Data("acsm".utf8).write(to: acsm)

  do {
    _ = try await ConversionService(tools: tools, adeptDirectory: workspace.adept).convert(
      acsm: acsm, destination: workspace.destination
    ) { _ in }
    Issue.record("Expected the conversion to fail")
  } catch ConversionError.commandFailed(let command, let output) {
    #expect(command == "acsmdownloader")
    #expect(output.contains("boom"))
  }
}
