import Foundation
import Testing

@testable import Lentera

@Test func normalizesKindleAddresses() {
  #expect(KindleDelivery.normalizedAddress("  reader_1@kindle.com \n") == "reader_1@kindle.com")
  #expect(KindleDelivery.normalizedAddress("") == nil)
  #expect(KindleDelivery.normalizedAddress("reader") == nil)
  #expect(KindleDelivery.normalizedAddress("@kindle.com") == nil)
  #expect(KindleDelivery.normalizedAddress("reader@kindle") == nil)
  #expect(KindleDelivery.normalizedAddress("reader@kindle.") == nil)
  #expect(KindleDelivery.normalizedAddress("rea der@kindle.com") == nil)
  #expect(KindleDelivery.normalizedAddress("a@b@kindle.com") == nil)
}

@Test func reportsKindleDeliveryProblems() throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }
  let small = directory.appendingPathComponent("small.epub")
  try Data("epub".utf8).write(to: small)
  let large = directory.appendingPathComponent("large.pdf")
  fileManager.createFile(atPath: large.path, contents: nil)
  let handle = try FileHandle(forWritingTo: large)
  try handle.truncate(atOffset: UInt64(KindleDelivery.maxAttachmentBytes + 1))
  try handle.close()

  #expect(KindleDelivery.problem(address: "reader@kindle.com", fileURL: small) == nil)
  #expect(KindleDelivery.problem(address: "", fileURL: small)?.title == "Kindle email not set")
  #expect(
    KindleDelivery.problem(
      address: "reader@kindle.com", fileURL: directory.appendingPathComponent("gone.epub")
    )?.title == "Book file not found")
  #expect(
    KindleDelivery.problem(address: "reader@kindle.com", fileURL: large)?.title
      == "Book is too large for email")
}
