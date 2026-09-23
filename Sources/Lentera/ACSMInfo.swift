import Foundation

/// What an ACSM license says about its book, read before the book is downloaded.
nonisolated struct ACSMInfo: Equatable, Sendable {
  let title: String?
  let author: String?
  let format: OutputFormat?
  let expiration: Date?
  let isLoan: Bool

  func isExpired(at now: Date = Date()) -> Bool {
    expiration.map { $0 <= now } ?? false
  }

  static func read(from data: Data) -> ACSMInfo? {
    guard let document = try? XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever]),
      document.rootElement()?.localName == "fulfillmentToken"
    else { return nil }
    let metadata = "//*[local-name()='resourceItemInfo']/*[local-name()='metadata']"
    let creators = strings(document, "\(metadata)/*[local-name()='creator']")
    let mimeType = strings(document, "\(metadata)/*[local-name()='format']").first
    let fulfillmentType = document.rootElement()?.attribute(forName: "fulfillmentType")?.stringValue
    return ACSMInfo(
      title: strings(document, "\(metadata)/*[local-name()='title']").first,
      author: creators.isEmpty ? nil : creators.joined(separator: ", "),
      format: mimeType.flatMap(format(forMIMEType:)),
      expiration: strings(document, "/*/*[local-name()='expiration']").first.flatMap(date(from:)),
      isLoan: fulfillmentType?.lowercased() == "loan"
    )
  }

  private static func format(forMIMEType type: String) -> OutputFormat? {
    switch type.lowercased() {
    case "application/epub+zip": .epub
    case "application/pdf": .pdf
    default: nil
    }
  }

  static func date(from text: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    if let date = formatter.date(from: text) { return date }
    formatter.formatOptions.insert(.withFractionalSeconds)
    return formatter.date(from: text)
  }

  private static func strings(_ document: XMLDocument, _ path: String) -> [String] {
    ((try? document.nodes(forXPath: path)) ?? []).compactMap {
      let value = $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
      return value?.isEmpty == false ? value : nil
    }
  }
}
