import Foundation
import Testing

@testable import Lentera

private func acsmXML(
  type: String = "buy", expiration: String = "2031-01-02T03:04:05+00:00",
  format: String = "application/epub+zip"
) -> Data {
  Data(
    """
    <?xml version="1.0"?>
    <fulfillmentToken fulfillmentType="\(type)" auth="user" xmlns="http://ns.adobe.com/adept">
      <distributor>urn:uuid:0</distributor>
      <expiration>\(expiration)</expiration>
      <resourceItemInfo>
        <resource>urn:uuid:1</resource>
        <metadata>
          <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/"> Bumi &amp; Langit </dc:title>
          <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">Tere Liye</dc:creator>
          <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">Co Author</dc:creator>
          <dc:format xmlns:dc="http://purl.org/dc/elements/1.1/">\(format)</dc:format>
        </metadata>
      </resourceItemInfo>
    </fulfillmentToken>
    """.utf8)
}

@Test func readsBookDetailsFromACSM() throws {
  let info = try #require(ACSMInfo.read(from: acsmXML()))
  #expect(info.title == "Bumi & Langit")
  #expect(info.author == "Tere Liye, Co Author")
  #expect(info.format == .epub)
  #expect(!info.isLoan)
  #expect(info.expiration == Date(timeIntervalSince1970: 1_925_089_445))
  #expect(!info.isExpired(at: Date(timeIntervalSince1970: 0)))
  #expect(info.isExpired(at: Date(timeIntervalSince1970: 2_000_000_000)))
}

@Test func readsLoansPDFsAndFractionalExpirations() throws {
  let info = try #require(
    ACSMInfo.read(
      from: acsmXML(
        type: "loan", expiration: "2031-01-02T03:04:05.250Z", format: "application/pdf")))
  #expect(info.isLoan)
  #expect(info.format == .pdf)
  #expect(info.expiration != nil)
}

@Test func rejectsFilesThatAreNotACSM() {
  #expect(ACSMInfo.read(from: Data("<html/>".utf8)) == nil)
  #expect(ACSMInfo.read(from: Data("not xml".utf8)) == nil)
}

@MainActor @Test func queueShowsTheTitleFromTheLicense() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("URLLink.acsm")
  try acsmXML().write(to: file)

  let model = ConversionModel(books: [])
  model.addFiles([file])
  #expect(model.queue.first?.displayName == "Bumi & Langit")
  #expect(model.queue.first?.info?.author == "Tere Liye, Co Author")
}
