import Foundation
import Testing

@testable import Lentera

@Test func mapsExpiredRequestToHelpfulMessage() {
  let message = FriendlyError.message(command: "acsmdownloader", output: "E_ADEPT_REQUEST_EXPIRED")
  #expect(message.contains("kedaluwarsa"))
}

@Test func keepsUnknownToolOutputOutOfTheSummary() {
  let message = FriendlyError.message(command: "adept_remove", output: "custom failure")
  #expect(!message.contains("custom failure"))
  #expect(message.contains("detail teknis"))
}

@Test func errorPresentationPreservesTechnicalOutput() {
  let error = ErrorPresentation.from(
    ConversionError.commandFailed("adept_remove", "custom failure"))
  #expect(error.summary.contains("detail teknis"))
  #expect(error.detail == "custom failure")
}

@Test func bookshelfRecordRoundTrips() throws {
  let record = BookRecord(
    id: UUID(),
    title: "Example",
    author: "Author",
    filePath: "/tmp/example.epub",
    format: .epub,
    coverPath: nil,
    completedAt: Date(timeIntervalSince1970: 1_700_000_000)
  )
  let decoded = try JSONDecoder().decode(
    BookRecord.self,
    from: JSONEncoder().encode(record)
  )
  #expect(decoded.filePath == record.filePath)
  #expect(decoded.format == .epub)
}
