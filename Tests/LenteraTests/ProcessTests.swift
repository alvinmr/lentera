import Darwin
import Foundation
import Testing
@testable import Lentera

@Test func cancellationStopsRunningProcess() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let task = Task {
    try await ConversionService().run(URL(fileURLWithPath: "/bin/sh"),
      ["-c", "echo $$ > pid; exec /bin/sleep 10"], currentDirectory: directory)
  }
  defer { task.cancel() }
  let pidFile = directory.appendingPathComponent("pid")
  for _ in 0..<200 {
    if FileManager.default.fileExists(atPath: pidFile.path) { break }
    try await Task.sleep(for: .milliseconds(10))
  }
  let pid = try #require(Int32(String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
  let start = ContinuousClock.now
  task.cancel()
  do {
    _ = try await task.value
    Issue.record("Cancellation must throw CancellationError")
  } catch is CancellationError {
  }
  #expect(start.duration(to: .now) < .seconds(3))
  #expect(kill(pid, 0) == -1)
}

@Test func failedProcessPreservesOutput() async throws {
  do {
    _ = try await ConversionService().run(URL(fileURLWithPath: "/bin/sh"),
      ["-c", "echo failure >&2; exit 7"], currentDirectory: FileManager.default.temporaryDirectory)
    Issue.record("Nonzero exit must throw")
  } catch ConversionError.commandFailed(let command, let output) {
    #expect(command == "sh")
    #expect(output.contains("failure"))
  }
}
