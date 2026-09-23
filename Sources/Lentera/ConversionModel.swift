import AppKit
import CryptoKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

nonisolated enum OutputFormat: String, CaseIterable, Codable, Identifiable, Sendable {
  case epub = "EPUB"
  case pdf = "PDF"
  var id: Self { self }
  var fileExtension: String { rawValue.lowercased() }
}

nonisolated enum AppPage: String, CaseIterable, Sendable {
  case convert
  case bookshelf
}

nonisolated enum ShelfFilter: String, CaseIterable, Sendable {
  case all = "All"
  case epub = "EPUB"
  case pdf = "PDF"
}

nonisolated enum ShelfSort: String, CaseIterable {
  case newest = "Newest"
  case oldest = "Oldest"
  case title = "Title A–Z"
}

nonisolated struct BookRecord: Codable, Identifiable, Sendable {
  let id: UUID
  var title: String
  var author: String?
  let filePath: String
  let format: OutputFormat
  var coverPath: String?
  let completedAt: Date
  var edited: Bool?
  var acsmFingerprint: String?
  /// The adept_loan_mgt ID when the book is a library loan.
  var loanID: String?
  var loanExpiresAt: Date?

  init(
    id: UUID, title: String, author: String?, filePath: String, format: OutputFormat,
    coverPath: String?, completedAt: Date, edited: Bool? = nil, acsmFingerprint: String? = nil,
    loan: Loan? = nil
  ) {
    self.id = id
    self.title = title
    self.author = author
    self.filePath = filePath
    self.format = format
    self.coverPath = coverPath
    self.completedAt = completedAt
    self.edited = edited
    self.acsmFingerprint = acsmFingerprint
    self.loanID = loan?.id
    self.loanExpiresAt = loan?.expiresAt
  }

  var fileURL: URL { URL(fileURLWithPath: filePath) }
  var coverURL: URL? { coverPath.map(URL.init(fileURLWithPath:)) }
  var isLoan: Bool { loanID != nil }

  func isLoanExpired(at now: Date = Date()) -> Bool {
    loanExpiresAt.map { $0 <= now } ?? false
  }
}

nonisolated enum CoverChange: Equatable, Sendable {
  case keep
  case replace(Data)
  /// Falls back to the generated cloth cover.
  case remove
}

nonisolated struct ConversionResult: Sendable {
  let fileURL: URL
  let title: String
  let author: String
  let format: OutputFormat
  let coverData: Data?
  var loan: Loan? = nil
}

nonisolated struct ErrorPresentation: Identifiable, Equatable {
  let id = UUID()
  let title: String
  let summary: String
  let detail: String

  static func from(_ error: Error) -> ErrorPresentation {
    if let conversion = error as? ConversionError {
      switch conversion {
      case .commandFailed(let command, let output):
        return ErrorPresentation(
          title: "Conversion failed",
          summary: FriendlyError.message(command: command, output: output),
          detail: output.isEmpty ? "No output from \(command)." : output
        )
      default:
        return ErrorPresentation(
          title: "Conversion failed",
          summary: conversion.localizedDescription,
          detail: String(describing: conversion)
        )
      }
    }
    return ErrorPresentation(
      title: "Conversion failed",
      summary: error.localizedDescription,
      detail: String(describing: error)
    )
  }
}

nonisolated enum QueueItemState: Equatable, Sendable {
  case waiting
  case active(progress: Double, message: String)
  case done(resultURL: URL)
  case failed(ErrorPresentation)
  case cancelled
}

nonisolated struct ConversionItem: Identifiable, Equatable, Sendable {
  let id: UUID
  let fileURL: URL
  let fingerprint: String?
  let info: ACSMInfo?
  var state: QueueItemState = .waiting

  init(id: UUID, fileURL: URL, fingerprint: String? = nil, info: ACSMInfo? = nil) {
    self.id = id
    self.fileURL = fileURL
    self.fingerprint = fingerprint
    self.info = info
  }

  /// The book title from the license, or the file name when the license has none.
  var displayName: String { info?.title ?? fileURL.lastPathComponent }

  var isWaiting: Bool { state == .waiting }
  var isActive: Bool { if case .active = state { true } else { false } }
  var isDone: Bool { if case .done = state { true } else { false } }
  var isFailed: Bool { if case .failed = state { true } else { false } }
  var canRetry: Bool { if case .failed = state { true } else { state == .cancelled } }
  var progress: Double { if case .active(let progress, _) = state { progress } else { 0 } }
  var message: String { if case .active(_, let message) = state { message } else { "" } }
  var resultURL: URL? { if case .done(let url) = state { url } else { nil } }
  var failure: ErrorPresentation? { if case .failed(let error) = state { error } else { nil } }
}

typealias ConversionOperation =
  @Sendable (URL, URL, @escaping @Sendable (ProgressUpdate) -> Void) async throws -> ConversionResult

typealias BatchNotifier = @MainActor (String, String) -> Void

typealias ReturnLoanOperation = @Sendable (String) async throws -> Void

@MainActor
@Observable
final class ConversionModel {
  var page: AppPage = .convert
  var shelfFilter: ShelfFilter = .all
  var shelfSearch = ""
  var shelfSort: ShelfSort = .newest
  var queue: [ConversionItem] = []
  var destination: URL?
  var isDropTargeted = false
  var isConverting = false
  var books: [BookRecord] = []
  var missingBookIDs: Set<UUID> = []
  /// Books converted in this session that have not been shown on the shelf yet.
  var recentlyAddedBookIDs: Set<UUID> = []
  var errorPresentation: ErrorPresentation?
  /// Loans that are being returned to the provider now.
  var returningBookIDs: Set<UUID> = []
  /// Set when the provider rate limits a conversion. Retries before this time can extend the limit.
  var rateLimitedUntil: Date?

  var waitingCount: Int { queue.filter(\.isWaiting).count }
  var succeededCount: Int { queue.filter(\.isDone).count }

  var overallProgress: Double {
    guard batchTotal > 0 else { return 0 }
    let active = queue.first(where: \.isActive)?.progress ?? 0
    return min(1, (Double(batchCompleted) + active) / Double(batchTotal))
  }

  var batchStatusText: String {
    guard isConverting else { return "" }
    let position = min(batchCompleted + 1, batchTotal)
    let name = queue.first(where: \.isActive)?.displayName ?? ""
    return batchTotal > 1 ? "Converting \(position) of \(batchTotal) · \(name)" : name
  }

  var visibleBooks: [BookRecord] {
    let query = shelfSearch.trimmingCharacters(in: .whitespacesAndNewlines)
    return books.filter { book in
      let matchesFormat = shelfFilter == .all || book.format.rawValue == shelfFilter.rawValue
      return matchesFormat && (query.isEmpty || book.title.localizedStandardContains(query)
        || (book.author?.localizedStandardContains(query) ?? false))
    }.sorted { lhs, rhs in
      switch shelfSort {
      case .newest where lhs.completedAt != rhs.completedAt: return lhs.completedAt > rhs.completedAt
      case .oldest where lhs.completedAt != rhs.completedAt: return lhs.completedAt < rhs.completedAt
      default:
        let order = lhs.title.localizedStandardCompare(rhs.title)
        return order == .orderedSame ? lhs.id.uuidString < rhs.id.uuidString : order == .orderedAscending
      }
    }
  }

  private var conversionTask: Task<Void, Never>?
  private var batchTotal = 0
  private var batchCompleted = 0
  private var batchSucceeded = 0
  private var batchFailed = 0
  private var batchCancelled = false
  private let convertOperation: ConversionOperation
  private let returnLoanOperation: ReturnLoanOperation
  private let notify: BatchNotifier

  init(
    books: [BookRecord]? = nil, convert: ConversionOperation? = nil,
    notify: BatchNotifier? = nil, returnLoan: ReturnLoanOperation? = nil
  ) {
    self.returnLoanOperation =
      returnLoan ?? { id in try await ConversionService().returnLoan(id: id) }
    self.convertOperation =
      convert ?? { acsm, destination, progress in
        try await ConversionService().convert(
          acsm: acsm, destination: destination, progress: progress)
      }
    self.notify = notify ?? { _, _ in }
    if let path = UserDefaults.standard.string(forKey: "destinationPath") {
      self.destination = URL(fileURLWithPath: path)
    }
    if let books {
      self.books = books
      return
    }
    if let data = UserDefaults.standard.data(forKey: "bookshelf"),
      let saved = try? JSONDecoder().decode([BookRecord].self, from: data)
    {
      self.books = saved
      Task { [weak self] in
        await self?.refreshBookMetadata()
        self?.linkLoans(LoanStore.all())
        self?.persistBooks()
      }
    }
  }

  func refreshBookMetadata() async {
    for book in books where book.edited != true {
      let hasCover = book.coverURL.flatMap { NSImage(contentsOf: $0) } != nil
      guard book.author == nil || !hasCover else { continue }
      let metadata = await BookMetadata.read(from: book.fileURL, fallbackTitle: book.title)
      guard let index = self.books.firstIndex(where: { $0.id == book.id }) else { continue }
      var updated = self.books[index]
      updated.title = metadata.title
      updated.author = book.author ?? metadata.author
      if !hasCover {
        // Drop a missing or broken cover even when the book has none to replace it.
        updated.coverPath = Self.saveCover(metadata.coverData, id: book.id)
        Self.deleteCover(book.coverPath)
      }
      self.books[index] = updated
    }
    refreshMissingFiles()
  }

  /// Books converted before Lentera tracked loans get their loan by title,
  /// when exactly one unlinked book has that title.
  func linkLoans(_ loans: [Loan]) {
    let linked = Set(books.compactMap(\.loanID))
    for loan in loans where !linked.contains(loan.id) && !loan.name.isEmpty {
      let matches = books.indices.filter {
        books[$0].loanID == nil
          && books[$0].title.localizedCaseInsensitiveCompare(loan.name) == .orderedSame
      }
      guard matches.count == 1 else { continue }
      books[matches[0]].loanID = loan.id
      books[matches[0]].loanExpiresAt = loan.expiresAt
    }
  }

  /// Returns the loan to the provider, then moves the book file to the Trash,
  /// because the book is no longer licensed to this device.
  func returnLoan(_ id: UUID) {
    guard let book = books.first(where: { $0.id == id }), let loanID = book.loanID,
      returningBookIDs.insert(id).inserted
    else { return }
    Task {
      defer { returningBookIDs.remove(id) }
      do {
        try await returnLoanOperation(loanID)
        Log.app.notice("Returned a loan")
        withAnimation(Motion.easeOut(0.2)) { trashBook(id) }
      } catch {
        let failure = ErrorPresentation.from(error)
        errorPresentation = ErrorPresentation(
          title: "Could not return “\(book.title)”", summary: failure.summary,
          detail: failure.detail)
      }
    }
  }

  func markBookLanded(_ id: UUID) {
    recentlyAddedBookIDs.remove(id)
  }

  func refreshMissingFiles() {
    missingBookIDs = Set(
      books.filter { !FileManager.default.fileExists(atPath: $0.filePath) }.map(\.id))
  }

  func openBook(_ book: BookRecord) {
    guard !missingBookIDs.contains(book.id) else { return }
    NSWorkspace.shared.open(book.fileURL)
  }

  func removeBook(_ id: UUID) {
    guard let index = books.firstIndex(where: { $0.id == id }) else { return }
    Self.deleteCover(books[index].coverPath)
    books.remove(at: index)
    missingBookIDs.remove(id)
    persistBooks()
  }

  func removeMissingBooks() {
    for book in books where missingBookIDs.contains(book.id) {
      Self.deleteCover(book.coverPath)
    }
    books.removeAll { missingBookIDs.contains($0.id) }
    missingBookIDs.removeAll()
    persistBooks()
  }

  func trashBook(_ id: UUID) {
    guard let book = books.first(where: { $0.id == id }) else { return }
    if FileManager.default.fileExists(atPath: book.filePath) {
      do {
        try FileManager.default.trashItem(at: book.fileURL, resultingItemURL: nil)
      } catch {
        errorPresentation = ErrorPresentation(
          title: "Could not move book to Trash",
          summary: error.localizedDescription,
          detail: String(describing: error)
        )
        return
      }
    }
    removeBook(id)
  }

  func updateBook(_ id: UUID, title: String, author: String?, cover: CoverChange = .keep) {
    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanTitle.isEmpty, let index = books.firstIndex(where: { $0.id == id }) else { return }
    let cleanAuthor = author?.trimmingCharacters(in: .whitespacesAndNewlines)
    var book = books[index]
    switch cover {
    case .keep:
      break
    case .replace(let data):
      guard let saved = Self.saveCover(data, id: id) else {
        errorPresentation = ErrorPresentation(
          title: "Could not use this image",
          summary: "Choose a JPEG, PNG, or HEIC image for the cover.",
          detail: "The image data could not be decoded or saved.")
        return
      }
      Self.deleteCover(book.coverPath)
      book.coverPath = saved
    case .remove:
      Self.deleteCover(book.coverPath)
      book.coverPath = nil
    }
    book.title = cleanTitle
    book.author = cleanAuthor?.isEmpty == true ? nil : cleanAuthor
    book.edited = true
    books[index] = book
    persistBooks()
  }

  func chooseFiles() {
    guard !isConverting else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [UTType(filenameExtension: "acsm") ?? .data]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.prompt = "Add"
    if panel.runModal() == .OK, !panel.urls.isEmpty { addFiles(panel.urls) }
  }

  func chooseDestination() {
    guard !isConverting else { return }
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.prompt = "Choose"
    if panel.runModal() == .OK, let url = panel.url {
      destination = url
      UserDefaults.standard.set(url.path, forKey: "destinationPath")
    }
  }

  func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
    let fileProviders = providers.filter {
      $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
    }
    guard !fileProviders.isEmpty else { return false }
    Task { @MainActor in
      var urls: [URL] = []
      for provider in fileProviders {
        if let url = await Self.fileURL(from: provider) { urls.append(url) }
      }
      addFiles(urls)
    }
    return true
  }

  func addFiles(_ urls: [URL]) {
    var known = Set(queue.map { Self.queueKey($0.fileURL) })
    var knownFingerprints = Set(books.compactMap(\.acsmFingerprint))
    var rejected: [URL] = []
    var alreadyConverted: [BookRecord] = []
    var added = 0
    for url in urls {
      guard url.pathExtension.lowercased() == "acsm" else {
        rejected.append(url)
        continue
      }
      guard known.insert(Self.queueKey(url)).inserted else { continue }
      let data = try? Data(contentsOf: url)
      let fingerprint = data.map(Self.fingerprint(of:))
      if let fingerprint {
        if let existing = books.first(where: { $0.acsmFingerprint == fingerprint }) {
          alreadyConverted.append(existing)
          continue
        }
        knownFingerprints.insert(fingerprint)
      }
      queue.append(
        ConversionItem(
          id: UUID(), fileURL: url, fingerprint: fingerprint, info: data.flatMap(ACSMInfo.read)))
      added += 1
    }
    if added > 0 { page = .convert }
    if !alreadyConverted.isEmpty {
      errorPresentation = ErrorPresentation(
        title: "Already converted",
        summary: alreadyConverted.count == 1
          ? "This ACSM was already converted to “\(alreadyConverted[0].title)”."
          : "\(alreadyConverted.count) files were already converted: "
            + alreadyConverted.map(\.title).joined(separator: ", ") + ".",
        detail: alreadyConverted.map(\.filePath).joined(separator: "\n")
      )
    } else if !rejected.isEmpty {
      errorPresentation = ErrorPresentation(
        title: rejected.count == 1 ? "Unsupported file" : "Some files are unsupported",
        summary: "Only files with the .acsm extension can be converted.",
        detail: rejected.map(\.path).joined(separator: "\n")
      )
    }
  }

  func removeItem(_ id: UUID) {
    guard !isConverting else { return }
    queue.removeAll { $0.id == id && !$0.isActive }
  }

  func clearFinished() {
    guard !isConverting else { return }
    queue.removeAll { !$0.isWaiting }
  }

  func convert() {
    guard !isConverting, waitingCount > 0 else { return }
    let outputDirectory =
      destination ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    isConverting = true
    errorPresentation = nil
    batchTotal = waitingCount
    batchCompleted = 0
    batchSucceeded = 0
    batchFailed = 0
    batchCancelled = false

    conversionTask = Task {
      defer {
        isConverting = false
        conversionTask = nil
        notifyBatchOutcome()
      }
      for index in queue.indices where queue[index].isWaiting {
        if Task.isCancelled { break }
        let id = queue[index].id
        let acsm = queue[index].fileURL
        queue[index].state = .active(progress: 0, message: "Preparing…")
        do {
          let result = try await convertOperation(acsm, outputDirectory) { [weak self] update in
            Task { @MainActor in
              guard let self, let task = self.conversionTask, !task.isCancelled else { return }
              guard let active = self.queue.firstIndex(where: \.isActive) else { return }
              self.queue[active].state = .active(
                progress: update.progress, message: update.message)
            }
          }
          batchCompleted += 1
          batchSucceeded += 1
          if let current = queue.firstIndex(where: { $0.id == id }) {
            queue[current].state = .done(resultURL: result.fileURL)
          }
          addBook(result, fingerprint: queue.first(where: { $0.id == id })?.fingerprint)
          Log.conversion.notice("Converted a book to \(result.format.rawValue, privacy: .public)")
        } catch is CancellationError {
          batchCancelled = true
          batchCompleted += 1
          if let current = queue.firstIndex(where: { $0.id == id }) {
            queue[current].state = .cancelled
          }
          break
        } catch {
          batchCompleted += 1
          batchFailed += 1
          Log.conversion.error("Conversion failed: \(String(describing: error), privacy: .private)")
          var failure = ErrorPresentation.from(error)
          let rateLimited = FriendlyError.isRateLimited(error)
          if rateLimited {
            let retryAt = Date().addingTimeInterval(FriendlyError.rateLimitCooldown)
            rateLimitedUntil = retryAt
            failure = ErrorPresentation(
              title: failure.title,
              summary: FriendlyError.rateLimitMessage(
                retryAt: retryAt, acsmExpiration: queue[index].info?.expiration),
              detail: failure.detail)
          }
          if let current = queue.firstIndex(where: { $0.id == id }) {
            queue[current].state = .failed(failure)
          }
          // The next files would hit the same limit and extend it, so they stay in the queue.
          if rateLimited { break }
        }
      }
    }
  }

  func retryItem(_ id: UUID) {
    guard !isConverting, let index = queue.firstIndex(where: { $0.id == id }) else { return }
    switch queue[index].state {
    case .failed, .cancelled: queue[index].state = .waiting
    case .waiting, .active, .done: return
    }
  }

  func cancel() {
    guard isConverting, conversionTask != nil else { return }
    if let active = queue.firstIndex(where: \.isActive) {
      queue[active].state = .active(progress: queue[active].progress, message: "Canceling…")
    }
    conversionTask?.cancel()
  }

  private func notifyBatchOutcome() {
    Log.app.notice(
      "Batch finished: \(self.batchSucceeded) succeeded, \(self.batchFailed) failed, cancelled \(self.batchCancelled, privacy: .public)"
    )
    guard !batchCancelled, batchSucceeded + batchFailed > 0 else { return }
    var body =
      batchSucceeded == 1 ? "1 book is ready to read." : "\(batchSucceeded) books are ready to read."
    if batchFailed > 0 {
      body += batchFailed == 1 ? " 1 file failed." : " \(batchFailed) files failed."
    }
    notify("Conversion finished", body)
  }

  private func addBook(_ result: ConversionResult, fingerprint: String?) {
    let id = UUID()
    let record = BookRecord(
      id: id,
      title: result.title,
      author: result.author,
      filePath: result.fileURL.path,
      format: result.format,
      coverPath: Self.saveCover(result.coverData, id: id),
      completedAt: Date(),
      acsmFingerprint: fingerprint,
      loan: result.loan
    )
    books.removeAll { $0.filePath == record.filePath }
    books.insert(record, at: 0)
    recentlyAddedBookIDs.insert(id)
    persistBooks()
  }

  private func persistBooks() {
    if let data = try? JSONEncoder().encode(books) {
      UserDefaults.standard.set(data, forKey: "bookshelf")
    }
  }

  private static func deleteCover(_ path: String?) {
    guard let path else { return }
    CoverCache.invalidate(path)
    try? FileManager.default.removeItem(atPath: path)
  }

  private static func queueKey(_ url: URL) -> String {
    url.standardizedFileURL.path.lowercased()
  }

  nonisolated static func fingerprint(of data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func fileURL(from provider: NSItemProvider) async -> URL? {
    await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
        if let data = item as? Data {
          continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
        } else {
          continuation.resume(returning: item as? URL)
        }
      }
    }
  }

  private static func saveCover(_ data: Data?, id: UUID) -> String? {
    guard let data, NSImage(data: data) != nil else { return nil }
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Lentera/covers", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      // A fresh name per save, so views keyed on the path pick up a replaced cover.
      let url = directory.appendingPathComponent("\(id.uuidString)-\(UUID().uuidString.prefix(8)).jpg")
      try data.write(to: url, options: .atomic)
      return url.path
    } catch {
      return nil
    }
  }
}
