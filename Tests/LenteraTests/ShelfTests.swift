import Foundation
import Testing
@testable import Lentera

@MainActor @Test func searchCombinesWithFormatAndSort() {
  let older = BookRecord(id: UUID(), title: "Zebra", author: "Jose", filePath: "/tmp/a.pdf",
    format: .pdf, coverPath: nil, completedAt: Date(timeIntervalSince1970: 1))
  let newer = BookRecord(id: UUID(), title: "Café", author: nil, filePath: "/tmp/b.epub",
    format: .epub, coverPath: nil, completedAt: Date(timeIntervalSince1970: 2))
  let model = ConversionModel(books: [older, newer])
  #expect(model.visibleBooks.map(\.id) == [newer.id, older.id])
  model.shelfSort = .oldest
  #expect(model.visibleBooks.map(\.id) == [older.id, newer.id])
  model.shelfSort = .title
  #expect(model.visibleBooks.map(\.id) == [newer.id, older.id])
  model.shelfSearch = "  CAFE  "
  #expect(model.visibleBooks.map(\.id) == [newer.id])
  model.shelfFilter = .pdf
  #expect(model.visibleBooks.isEmpty)
  model.shelfSearch = "JOSE"
  #expect(model.visibleBooks.map(\.id) == [older.id])
  model.shelfSearch = "  "
  model.shelfFilter = .all
  #expect(model.visibleBooks.count == 2)
  #expect(model.books.map(\.id) == [older.id, newer.id])
}
