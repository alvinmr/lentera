import Foundation
import Testing

@testable import Lentera

private func makeBook(
  path: String, title: String = "Book", author: String? = "Author"
) -> BookRecord {
  BookRecord(
    id: UUID(), title: title, author: author, filePath: path,
    format: .epub, coverPath: nil, completedAt: Date(timeIntervalSince1970: 1))
}

@MainActor @Test func detectsAndClearsMissingBookFiles() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  let file = directory.appendingPathComponent("book.epub")
  try Data("epub".utf8).write(to: file)
  let book = makeBook(path: file.path)
  let model = ConversionModel(books: [book])

  model.refreshMissingFiles()
  #expect(model.missingBookIDs.isEmpty)

  try fileManager.removeItem(at: file)
  model.refreshMissingFiles()
  #expect(model.missingBookIDs == [book.id])

  model.removeMissingBooks()
  #expect(model.books.isEmpty)
  #expect(model.missingBookIDs.isEmpty)
}

@MainActor @Test func updatingBookKeepsEditedValues() {
  let book = makeBook(path: "/tmp/\(UUID().uuidString).epub")
  let model = ConversionModel(books: [book])

  model.updateBook(book.id, title: "  New Title  ", author: " New Author ")
  #expect(model.books.first?.title == "New Title")
  #expect(model.books.first?.author == "New Author")
  #expect(model.books.first?.edited == true)

  model.updateBook(book.id, title: "   ", author: nil)
  #expect(model.books.first?.title == "New Title")

  model.updateBook(book.id, title: "New Title", author: nil)
  #expect(model.books.first?.author == nil)
}

@MainActor @Test func trashingMissingBookRemovesRecordWithoutError() {
  let book = makeBook(path: "/tmp/\(UUID().uuidString).epub")
  let model = ConversionModel(books: [book])

  model.trashBook(book.id)
  #expect(model.books.isEmpty)
  #expect(model.errorPresentation == nil)
}

@Test func bookRecordDecodesLegacyDataWithoutEditedKey() throws {
  let legacy = """
    {"id":"\(UUID().uuidString)","title":"Legacy","format":"EPUB",
     "filePath":"/tmp/legacy.epub","completedAt":0}
    """
  let decoded = try JSONDecoder().decode(BookRecord.self, from: Data(legacy.utf8))
  #expect(decoded.title == "Legacy")
  #expect(decoded.edited == nil)
}
