import Foundation
import Testing

@testable import Lentera

private func acsm(_ name: String) -> URL {
  URL(fileURLWithPath: "/tmp/\(name)")
}

private func label(_ state: QueueItemState) -> String {
  switch state {
  case .waiting: "waiting"
  case .active: "active"
  case .done: "done"
  case .failed: "failed"
  case .cancelled: "cancelled"
  }
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
  #expect(model.queue.allSatisfy { $0.isWaiting })
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
      progress(ProgressUpdate(progress: 0.5, message: "Downloading…"))
      if file.lastPathComponent == "bad.acsm" { throw ConversionError.invalidInput }
      let title = file.deletingPathExtension().lastPathComponent
      return ConversionResult(
        fileURL: destination.appendingPathComponent("\(title).epub"),
        title: title, author: "Author", format: .epub, coverData: nil)
    })
  model.addFiles([acsm("one.acsm"), acsm("bad.acsm"), acsm("two.acsm")])
  model.convert()
  try await waitForBatch(model)
  #expect(model.queue.map { label($0.state) } == ["done", "failed", "done"])
  #expect(model.queue[1].failure != nil)
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
  for _ in 0..<600 where model.queue.first?.isActive != true {
    try await Task.sleep(for: .milliseconds(10))
  }
  #expect(model.queue.first?.isActive == true)
  model.cancel()
  try await waitForBatch(model)
  #expect(model.queue[0].state == .cancelled)
  #expect(model.queue[1].isWaiting)
}

@MainActor @Test func clearFinishedKeepsWaitingItems() {
  let model = ConversionModel(books: [])
  model.addFiles([acsm("one.acsm"), acsm("two.acsm")])
  model.removeItem(model.queue[1].id)
  #expect(model.queue.map(\.fileURL.lastPathComponent) == ["one.acsm"])
}

@MainActor @Test func retryMovesFailedItemBackToWaiting() async throws {
  let model = ConversionModel(
    books: [], convert: { _, _, _ in throw ConversionError.invalidInput })
  model.addFiles([acsm("one.acsm")])
  model.convert()
  try await waitForBatch(model)
  #expect(model.queue[0].isFailed)
  model.retryItem(model.queue[0].id)
  #expect(model.queue[0].isWaiting)
}

@MainActor @Test func retryIsIgnoredWhileConverting() async throws {
  let model = ConversionModel(
    books: [],
    convert: { _, _, _ in
      try await Task.sleep(for: .seconds(30))
      throw ConversionError.invalidInput
    })
  model.addFiles([acsm("one.acsm")])
  model.convert()
  for _ in 0..<600 where model.queue.first?.isActive != true {
    try await Task.sleep(for: .milliseconds(10))
  }
  model.retryItem(model.queue[0].id)
  #expect(model.queue[0].isActive)
  model.cancel()
  try await waitForBatch(model)
}

@MainActor @Test func notifiesOnceWhenBatchFinishes() async throws {
  var notifications: [String] = []
  let model = ConversionModel(
    books: [],
    convert: { file, destination, _ in
      let title = file.deletingPathExtension().lastPathComponent
      return ConversionResult(
        fileURL: destination.appendingPathComponent("\(title).epub"),
        title: title, author: "Author", format: .epub, coverData: nil)
    },
    notify: { _, body in notifications.append(body) })
  model.addFiles([acsm("one.acsm"), acsm("two.acsm")])
  model.convert()
  try await waitForBatch(model)
  #expect(notifications == ["2 books are ready to read."])
}

@MainActor @Test func cancelDoesNotNotify() async throws {
  var notifications = 0
  let model = ConversionModel(
    books: [],
    convert: { _, _, _ in
      try await Task.sleep(for: .seconds(30))
      throw ConversionError.invalidInput
    },
    notify: { _, _ in notifications += 1 })
  model.addFiles([acsm("one.acsm")])
  model.convert()
  for _ in 0..<600 where model.queue.first?.isActive != true {
    try await Task.sleep(for: .milliseconds(10))
  }
  model.cancel()
  try await waitForBatch(model)
  #expect(notifications == 0)
}

@MainActor @Test func skipsAlreadyConvertedFiles() async throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  let acsmURL = directory.appendingPathComponent("book.acsm")
  try Data("same-license".utf8).write(to: acsmURL)

  let model = ConversionModel(
    books: [],
    convert: { _, destination, _ in
      ConversionResult(
        fileURL: destination.appendingPathComponent("Book.epub"),
        title: "Book", author: "Author", format: .epub, coverData: nil)
    })
  model.addFiles([acsmURL])
  model.convert()
  try await waitForBatch(model)
  #expect(model.books.first?.acsmFingerprint != nil)

  model.clearFinished()
  model.addFiles([acsmURL])
  #expect(model.queue.isEmpty)
  #expect(model.errorPresentation?.title == "Already converted")

  let copyURL = directory.appendingPathComponent("copy.acsm")
  try Data("same-license".utf8).write(to: copyURL)
  model.errorPresentation = nil
  model.addFiles([copyURL])
  #expect(model.queue.isEmpty)
  #expect(model.errorPresentation?.title == "Already converted")
}

@MainActor @Test func loadsSavedDestination() {
  let defaults = UserDefaults.standard
  let previous = defaults.string(forKey: "destinationPath")
  defer {
    if let previous {
      defaults.set(previous, forKey: "destinationPath")
    } else {
      defaults.removeObject(forKey: "destinationPath")
    }
  }
  defaults.set("/tmp/lentera-destination", forKey: "destinationPath")
  let model = ConversionModel(books: [])
  #expect(model.destination?.path == "/tmp/lentera-destination")
}
