import Foundation
import Testing

@testable import Lentera

private func acsm(_ name: String) -> URL {
  URL(fileURLWithPath: "/tmp/\(name)")
}

@MainActor
private func waitForBatch(_ model: ConversionModel) async throws {
  for _ in 0..<600 where model.isConverting {
    try await Task.sleep(for: .milliseconds(10))
  }
  #expect(!model.isConverting)
}

@MainActor @Test func addFilesKeepsUniqueACSMFilesInOrder() {
  let model = ConversionModel(books: [])
  model.addFiles([acsm("a.acsm"), acsm("notes.epub"), acsm("A.ACSM"), acsm("c.acsm")])
  #expect(model.queue.map(\.fileURL.lastPathComponent) == ["a.acsm", "c.acsm"])
  #expect(model.queue.allSatisfy { $0.status == .waiting })
}

@MainActor @Test func addFilesReportsRejectedFiles() {
  let model = ConversionModel(books: [])
  model.addFiles([acsm("cover.jpg")])
  #expect(model.queue.isEmpty)
  #expect(model.errorPresentation?.summary.contains(".acsm") == true)
}

@MainActor @Test func batchConversionContinuesAfterFailure() async throws {
  let model = ConversionModel(
    books: [],
    convert: { file, destination, progress in
      progress(ProgressUpdate(progress: 0.5, message: "Mengunduh buku…"))
      if file.lastPathComponent == "bad.acsm" { throw ConversionError.invalidInput }
      let title = file.deletingPathExtension().lastPathComponent
      return ConversionResult(
        fileURL: destination.appendingPathComponent("\(title).epub"),
        title: title, author: "Penulis", format: .epub, coverData: nil)
    })
  model.addFiles([acsm("one.acsm"), acsm("bad.acsm"), acsm("two.acsm")])
  model.convert()
  try await waitForBatch(model)
  #expect(model.queue.map(\.status) == [.done, .failed, .done])
  #expect(model.queue[1].error != nil)
  #expect(model.books.map(\.title) == ["two", "one"])
  #expect(model.succeededCount == 2)
  #expect(model.waitingCount == 0)
}

@MainActor @Test func cancellingStopsBatchAndLeavesRestWaiting() async throws {
  let model = ConversionModel(
    books: [],
    convert: { _, _, _ in
      try await Task.sleep(for: .seconds(30))
      throw ConversionError.invalidInput
    })
  model.addFiles([acsm("one.acsm"), acsm("two.acsm")])
  model.convert()
  for _ in 0..<600 where model.queue.first?.status != .active {
    try await Task.sleep(for: .milliseconds(10))
  }
  #expect(model.queue.first?.status == .active)
  model.cancel()
  try await waitForBatch(model)
  #expect(model.queue[0].status == .cancelled)
  #expect(model.queue[1].status == .waiting)
}

@MainActor @Test func clearFinishedKeepsWaitingItems() {
  let model = ConversionModel(books: [])
  model.addFiles([acsm("one.acsm"), acsm("two.acsm")])
  model.removeItem(model.queue[1].id)
  #expect(model.queue.map(\.fileURL.lastPathComponent) == ["one.acsm"])
}
