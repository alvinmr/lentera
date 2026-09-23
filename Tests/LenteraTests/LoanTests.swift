import Foundation
import Testing

@testable import Lentera

private func loanXML(name: String = "Laut Bercerita", validity: String = "2031-01-02T03:04:05+00:00")
  -> String
{
  """
  <?xml version="1.0"?>
  <loanToken>
    <id>urn:uuid:loan</id>
    <operatorURL>https://example.invalid/fulfillment</operatorURL>
    <validity>\(validity)</validity>
    <name>\(name)</name>
  </loanToken>
  """
}

private func script(_ body: String, at url: URL) throws {
  try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}

private func workspace() throws -> URL {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(
    at: root.appendingPathComponent("adept/loans"), withIntermediateDirectories: true)
  try FileManager.default.createDirectory(
    at: root.appendingPathComponent("tools"), withIntermediateDirectories: true)
  try FileManager.default.createDirectory(
    at: root.appendingPathComponent("out"), withIntermediateDirectories: true)
  try Data().write(to: root.appendingPathComponent("adept/activation.xml"))
  return root
}

@Test func readsLoanTokens() throws {
  let root = try workspace()
  defer { try? FileManager.default.removeItem(at: root) }
  let adept = root.appendingPathComponent("adept")
  try loanXML().write(
    to: LoanStore.file(for: "abc123", in: adept), atomically: true, encoding: .utf8)
  try "<loanToken/>".write(
    to: LoanStore.file(for: "broken", in: adept), atomically: true, encoding: .utf8)

  let loans = LoanStore.all(in: adept)
  #expect(loans.count == 1)
  #expect(loans.first?.id == "abc123")
  #expect(loans.first?.name == "Laut Bercerita")
  #expect(loans.first?.expiresAt == Date(timeIntervalSince1970: 1_925_089_445))
  #expect(loans.first?.isExpired(at: Date(timeIntervalSince1970: 2_000_000_000)) == true)

  let output = "Download...\nLoan token serialized into \(adept.path)/loans/abc123.xml\nDone"
  #expect(LoanStore.loan(fromDownloaderOutput: output)?.id == "abc123")
  #expect(LoanStore.loan(fromDownloaderOutput: "Done") == nil)
}

@Test func conversionRecordsTheLoanFromTheDownloader() async throws {
  let root = try workspace()
  defer { try? FileManager.default.removeItem(at: root) }
  let tools = root.appendingPathComponent("tools")
  try script("cp \"$5\" \"$4\"", at: tools.appendingPathComponent("adept_remove"))
  try script("true", at: tools.appendingPathComponent("adept_activate"))
  // Like acsmdownloader, write the token next to the activation and report its path.
  try script(
    """
    printf 'fake-epub' > "$PWD/downloaded.epub"
    cat > "$2/loans/f00d.xml" <<'XML'
    \(loanXML())
    XML
    echo "Loan token serialized into $2/loans/f00d.xml"
    """, at: tools.appendingPathComponent("acsmdownloader"))
  let locator = ToolLocator(
    activate: tools.appendingPathComponent("adept_activate"),
    downloader: tools.appendingPathComponent("acsmdownloader"),
    remove: tools.appendingPathComponent("adept_remove"))
  let acsm = root.appendingPathComponent("book.acsm")
  try Data("acsm".utf8).write(to: acsm)

  let result = try await ConversionService(
    tools: locator, adeptDirectory: root.appendingPathComponent("adept")
  ).convert(acsm: acsm, destination: root.appendingPathComponent("out")) { _ in }

  #expect(result.loan?.id == "f00d")
  #expect(result.loan?.name == "Laut Bercerita")
}

@Test(arguments: [true, false])
func returningALoanChecksThatTheTokenIsGone(toolRemovesToken: Bool) async throws {
  let root = try workspace()
  defer { try? FileManager.default.removeItem(at: root) }
  let adept = root.appendingPathComponent("adept")
  let tools = root.appendingPathComponent("tools")
  let token = LoanStore.file(for: "abc123", in: adept)
  try loanXML().write(to: token, atomically: true, encoding: .utf8)
  let loanTool = tools.appendingPathComponent("adept_loan_mgt")
  // adept_loan_mgt exits 0 even when the return fails.
  try script(
    toolRemovesToken
      ? "[ \"$3\" = \"-r\" ] && rm \"$2/loans/$4.xml\" && echo returned"
      : "echo 'Error : Loan abc123 doesn t exists'", at: loanTool)
  let locator = ToolLocator(activate: loanTool, downloader: loanTool, remove: loanTool, loans: loanTool)
  let service = ConversionService(tools: locator, adeptDirectory: adept)

  if toolRemovesToken {
    try await service.returnLoan(id: "abc123")
    #expect(!FileManager.default.fileExists(atPath: token.path))
    await #expect(throws: ConversionError.self) { try await service.returnLoan(id: "abc123") }
  } else {
    await #expect(throws: ConversionError.self) { try await service.returnLoan(id: "abc123") }
    #expect(FileManager.default.fileExists(atPath: token.path))
  }
}

private func loanBook(title: String = "Book", loanID: String? = "abc") -> BookRecord {
  BookRecord(
    id: UUID(), title: title, author: nil, filePath: "/tmp/\(UUID().uuidString).epub",
    format: .epub, coverPath: nil, completedAt: Date(),
    loan: loanID.map { Loan(id: $0, name: title, expiresAt: nil) })
}

@MainActor @Test func returnedLoansLeaveTheShelf() async throws {
  let book = loanBook()
  let model = ConversionModel(books: [book], returnLoan: { id in #expect(id == "abc") })
  model.returnLoan(book.id)
  #expect(model.returningBookIDs == [book.id])
  for _ in 0..<200 where !model.returningBookIDs.isEmpty {
    try await Task.sleep(for: .milliseconds(5))
  }
  #expect(model.books.isEmpty)
  #expect(model.errorPresentation == nil)
}

@MainActor @Test func failedReturnsKeepTheBook() async throws {
  let book = loanBook()
  let model = ConversionModel(books: [book], returnLoan: { _ in throw ConversionError.loanMissing })
  model.returnLoan(book.id)
  for _ in 0..<200 where !model.returningBookIDs.isEmpty {
    try await Task.sleep(for: .milliseconds(5))
  }
  #expect(model.books.map(\.id) == [book.id])
  #expect(model.errorPresentation?.title.contains("Book") == true)
}

@MainActor @Test func linksOlderBooksToLoansByUniqueTitle() {
  let unique = loanBook(title: "Laut Bercerita", loanID: nil)
  let twinA = loanBook(title: "Twin", loanID: nil)
  let twinB = loanBook(title: "Twin", loanID: nil)
  let model = ConversionModel(books: [unique, twinA, twinB])
  let end = Date(timeIntervalSince1970: 2_000_000_000)
  model.linkLoans([
    Loan(id: "one", name: "laut bercerita", expiresAt: end),
    Loan(id: "two", name: "Twin", expiresAt: nil),
  ])
  #expect(model.books[0].loanID == "one")
  #expect(model.books[0].loanExpiresAt == end)
  #expect(model.books[1].loanID == nil && model.books[2].loanID == nil)
}
