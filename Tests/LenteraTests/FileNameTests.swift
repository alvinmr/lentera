import Foundation
import Testing

@testable import Lentera

@Test func safeBaseNameReplacesIllegalCharacters() {
  let service = ConversionService()
  #expect(service.safeBaseName("A/B\\C:D") == "A B C D")
  #expect(service.safeBaseName("  ..Title..  ") == "Title")
  #expect(service.safeBaseName("...") == "Book")
  #expect(service.safeBaseName("") == "Book")
  #expect(service.safeBaseName("ANOMALI \u{2029}Memoar\nSeorang  Bipolar") == "ANOMALI Memoar Seorang Bipolar")
}

@Test func safeBaseNameTruncatesLongTitles() {
  let service = ConversionService()
  #expect(service.safeBaseName(String(repeating: "a", count: 200)).count == 120)
}

@Test func uniqueDestinationAppendsSuffixWhenFileExists() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  let service = ConversionService()

  let first = service.uniqueDestination(directory: directory, baseName: "Book", extension: "epub")
  #expect(first.lastPathComponent == "Book.epub")

  try Data("one".utf8).write(to: first)
  let second = service.uniqueDestination(directory: directory, baseName: "Book", extension: "epub")
  #expect(second.lastPathComponent == "Book 2.epub")

  try Data("two".utf8).write(to: second)
  let third = service.uniqueDestination(directory: directory, baseName: "Book", extension: "epub")
  #expect(third.lastPathComponent == "Book 3.epub")
}
