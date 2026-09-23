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

@MainActor @Test func editingKeepsFingerprintAndReplacesCover() throws {
  let book = BookRecord(
    id: UUID(), title: "Book", author: nil, filePath: "/tmp/\(UUID().uuidString).epub",
    format: .epub, coverPath: nil, completedAt: Date(), acsmFingerprint: "abc")
  let model = ConversionModel(books: [book])
  let png = try #require(Data(base64Encoded:
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aE1sAAAAASUVORK5CYII="))

  model.updateBook(book.id, title: "Book", author: nil, cover: .replace(png))
  let first = try #require(model.books.first?.coverPath)
  #expect(model.books.first?.acsmFingerprint == "abc")
  #expect(try Data(contentsOf: URL(fileURLWithPath: first)) == png)

  model.updateBook(book.id, title: "Book", author: nil, cover: .replace(png))
  let second = try #require(model.books.first?.coverPath)
  #expect(second != first)
  #expect(!FileManager.default.fileExists(atPath: first))

  model.updateBook(book.id, title: "Book", author: nil, cover: .remove)
  #expect(model.books.first?.coverPath == nil)
  #expect(!FileManager.default.fileExists(atPath: second))

  model.updateBook(book.id, title: "Book", author: nil, cover: .replace(Data("nope".utf8)))
  #expect(model.errorPresentation != nil)
  #expect(model.books.first?.coverPath == nil)
}
