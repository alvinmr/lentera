import Foundation

/// A library loan that acsmdownloader saved as `loans/<id>.xml` in the activation folder.
nonisolated struct Loan: Equatable, Sendable {
  /// The file name without `.xml`, which adept_loan_mgt takes as the loan ID.
  let id: String
  let name: String
  let expiresAt: Date?

  func isExpired(at now: Date = Date()) -> Bool {
    expiresAt.map { $0 <= now } ?? false
  }
}

nonisolated enum LoanStore {
  static func directory(in adept: URL) -> URL {
    adept.appendingPathComponent("loans", isDirectory: true)
  }

  static func file(for id: String, in adept: URL) -> URL {
    directory(in: adept).appendingPathComponent("\(id).xml")
  }

  static func all(in adept: URL = AdobeActivation.directory) -> [Loan] {
    let files =
      (try? FileManager.default.contentsOfDirectory(
        at: directory(in: adept), includingPropertiesForKeys: nil)) ?? []
    return files.filter { $0.pathExtension == "xml" }.compactMap(read)
  }

  static func read(_ file: URL) -> Loan? {
    guard let document = try? XMLDocument(contentsOf: file, options: [.nodeLoadExternalEntitiesNever])
    else { return nil }
    func text(_ name: String) -> String? {
      let node = try? document.nodes(forXPath: "/loanToken/\(name)").first
      let value = node?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
      return value?.isEmpty == false ? value : nil
    }
    guard text("id") != nil else { return nil }
    return Loan(
      id: file.deletingPathExtension().lastPathComponent,
      name: text("name") ?? "",
      expiresAt: text("validity").flatMap(ACSMInfo.date(from:)))
  }

  /// acsmdownloader prints "Loan token serialized into <path>" when the book is a loan.
  static func loan(fromDownloaderOutput output: String) -> Loan? {
    let marker = "Loan token serialized into "
    guard let line = output.split(whereSeparator: \.isNewline).last(where: { $0.contains(marker) }),
      let range = line.range(of: marker)
    else { return nil }
    let path = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
    return read(URL(fileURLWithPath: path))
  }
}
