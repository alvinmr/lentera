import Foundation
import Testing

@testable import Lentera

@Test func mapsExpiredRequestToHelpfulMessage() {
  let message = FriendlyError.message(command: "acsmdownloader", output: "E_ADEPT_REQUEST_EXPIRED")
  #expect(message.contains("expired"))
}

@Test func keepsUnknownToolOutputOutOfTheSummary() {
  let message = FriendlyError.message(command: "adept_remove", output: "custom failure")
  #expect(!message.contains("custom failure"))
  #expect(message.contains("technical details"))
}

@Test func errorPresentationPreservesTechnicalOutput() {
  let error = ErrorPresentation.from(
    ConversionError.commandFailed("adept_remove", "custom failure"))
  #expect(error.summary.contains("technical details"))
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

@Test func rateLimitMessageAsksForANewACSMWhenItExpiresFirst() {
  let retryAt = Date(timeIntervalSince1970: 2_000_000_000)
  let expiresFirst = FriendlyError.rateLimitMessage(
    retryAt: retryAt, acsmExpiration: retryAt.addingTimeInterval(-60))
  #expect(expiresFirst.contains("download a new ACSM"))

  let stillValid = FriendlyError.rateLimitMessage(
    retryAt: retryAt, acsmExpiration: retryAt.addingTimeInterval(3600))
  #expect(stillValid.contains("try once"))
  #expect(!stillValid.contains("new ACSM"))
  #expect(FriendlyError.rateLimitMessage(retryAt: retryAt, acsmExpiration: nil).contains("try once"))
}

@Test func detectsRateLimitedConversions() {
  #expect(FriendlyError.isRateLimited(
    ConversionError.commandFailed("acsmdownloader", "Message : HTTP Error code 429")))
  #expect(!FriendlyError.isRateLimited(
    ConversionError.commandFailed("acsmdownloader", "HTTP Error code 500")))
  #expect(!FriendlyError.isRateLimited(ConversionError.invalidInput))
}
