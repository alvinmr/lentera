import AppKit

nonisolated enum KindleDelivery {
  /// Amazon rejects email attachments larger than 50 MB.
  static let maxAttachmentBytes: Int64 = 50 * 1024 * 1024

  static func normalizedAddress(_ address: String) -> String? {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
      !parts[1].hasPrefix("."), !parts[1].hasSuffix("."),
      !trimmed.contains(where: \.isWhitespace)
    else { return nil }
    return trimmed
  }

  static func problem(address: String, fileURL: URL) -> ErrorPresentation? {
    guard normalizedAddress(address) != nil else {
      return ErrorPresentation(
        title: "Kindle email not set",
        summary: "Enter your Send to Kindle email address in Settings (⌘,).",
        detail: "Find the address on Amazon under Manage Your Content and Devices > Preferences > Personal Document Settings."
      )
    }
    let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
    guard let size else {
      return ErrorPresentation(
        title: "Book file not found",
        summary: "Lentera cannot find the file for this book.",
        detail: fileURL.path
      )
    }
    guard size <= maxAttachmentBytes else {
      return ErrorPresentation(
        title: "Book is too large for email",
        summary: "Send to Kindle email accepts files up to 50 MB. Use the Send to Kindle website for this book.",
        detail: "\(fileURL.path)\n\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
      )
    }
    return nil
  }
}

extension ConversionModel {
  func sendToKindle(_ book: BookRecord, address: String) {
    if let problem = KindleDelivery.problem(address: address, fileURL: book.fileURL) {
      errorPresentation = problem
      return
    }
    guard let recipient = KindleDelivery.normalizedAddress(address) else { return }
    guard let service = NSSharingService(named: .composeEmail),
      service.canPerform(withItems: [book.fileURL])
    else {
      errorPresentation = ErrorPresentation(
        title: "Mail is not available",
        summary: "Set up an account in the Mail app, or send the file from the Send to Kindle website.",
        detail: book.filePath
      )
      return
    }
    service.recipients = [recipient]
    service.subject = book.title
    service.perform(withItems: [book.fileURL])
  }
}
