import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum OutputFormat: String, CaseIterable, Codable, Identifiable, Sendable {
  case epub = "EPUB"
  case pdf = "PDF"
  var id: Self { self }
  var fileExtension: String { rawValue.lowercased() }
}

enum AppPage: String, CaseIterable, Sendable {
  case convert
  case bookshelf
}

enum ShelfFilter: String, CaseIterable, Sendable {
  case all = "Semua"
  case epub = "EPUB"
  case pdf = "PDF"
}

enum ShelfSort: String, CaseIterable {
  case newest = "Terbaru"
  case oldest = "Terlama"
  case title = "Judul A–Z"
}

struct BookRecord: Codable, Identifiable, Sendable {
  let id: UUID
  let title: String
  let author: String?
  let filePath: String
  let format: OutputFormat
  let coverPath: String?
  let completedAt: Date

  var fileURL: URL { URL(fileURLWithPath: filePath) }
  var coverURL: URL? { coverPath.map(URL.init(fileURLWithPath:)) }
}

struct ConversionResult: Sendable {
  let fileURL: URL
  let title: String
  let author: String
  let format: OutputFormat
  let coverData: Data?
}

struct ErrorPresentation: Identifiable {
  let id = UUID()
  let title: String
  let summary: String
  let detail: String

  static func from(_ error: Error) -> ErrorPresentation {
    if let conversion = error as? ConversionError {
      switch conversion {
      case .commandFailed(let command, let output):
        return ErrorPresentation(
          title: "Konversi gagal",
          summary: FriendlyError.message(command: command, output: output),
          detail: output.isEmpty ? "Tidak ada keluaran dari \(command)." : output
        )
      default:
        return ErrorPresentation(
          title: "Konversi gagal",
          summary: conversion.localizedDescription,
          detail: String(describing: conversion)
        )
      }
    }
    return ErrorPresentation(
      title: "Konversi gagal",
      summary: error.localizedDescription,
      detail: String(describing: error)
    )
  }
}

@MainActor
@Observable
final class ConversionModel {
  var page: AppPage = .convert
  var shelfFilter: ShelfFilter = .all
  var shelfSearch = ""
  var shelfSort: ShelfSort = .newest
  var selectedFile: URL?
  var destination: URL?
  var isDropTargeted = false
  var isConverting = false
  var progress = 0.0
  var statusText = "Mempersiapkan…"
  var resultFile: URL?
  var books: [BookRecord] = []
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
  var errorPresentation: ErrorPresentation?

  private var conversionTask: Task<Void, Never>?

  init(books: [BookRecord]? = nil) {
    if let books {
      self.books = books
      return
    }
    if let data = UserDefaults.standard.data(forKey: "bookshelf"),
      let saved = try? JSONDecoder().decode([BookRecord].self, from: data)
    {
      self.books = saved
      Task { [weak self] in
        for book in saved where book.format == .epub && (book.author == nil || book.coverPath == nil) {
          let metadata = await Task.detached(priority: .utility) {
            BookMetadata.read(from: book.fileURL, fallbackTitle: book.title)
          }.value
          guard let self else { return }
          guard let index = self.books.firstIndex(where: { $0.id == book.id }) else { continue }
          self.books[index] = BookRecord(
            id: book.id, title: metadata.title, author: book.author ?? metadata.author,
            filePath: book.filePath, format: book.format,
            coverPath: book.coverPath ?? Self.saveCover(metadata.coverData, id: book.id),
            completedAt: book.completedAt)
        }
        if let self, let refreshed = try? JSONEncoder().encode(self.books) {
          UserDefaults.standard.set(refreshed, forKey: "bookshelf")
        }
      }
    }
  }

  func chooseFile() {
    guard !isConverting else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [UTType(filenameExtension: "acsm") ?? .data]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    if panel.runModal() == .OK, let url = panel.url { select(url) }
  }

  func chooseDestination() {
    guard !isConverting else { return }
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.prompt = "Pilih"
    if panel.runModal() == .OK { destination = panel.url }
  }

  func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
    guard !isConverting else { return false }
    guard
      let provider = providers.first(where: {
        $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
      })
    else {
      return false
    }
    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
      [weak self] item, _ in
      let url: URL?
      if let data = item as? Data {
        url = URL(dataRepresentation: data, relativeTo: nil)
      } else {
        url = item as? URL
      }
      guard let url else { return }
      Task { @MainActor in self?.select(url) }
    }
    return true
  }

  func convert() {
    guard !isConverting, let selectedFile else { return }
    let outputDirectory =
      destination ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    isConverting = true
    resultFile = nil
    errorPresentation = nil
    progress = 0.05
    statusText = "Memeriksa mesin konversi…"

    conversionTask = Task {
      defer {
        isConverting = false
        conversionTask = nil
      }
      do {
        let result = try await ConversionService().convert(
          acsm: selectedFile,
          destination: outputDirectory
        ) { [weak self] update in
          Task { @MainActor in
            guard let self, let task = self.conversionTask, !task.isCancelled else { return }
            self.progress = update.progress
            self.statusText = update.message
          }
        }
        resultFile = result.fileURL
        addBook(result)
      } catch is CancellationError {
        statusText = "Dibatalkan"
      } catch {
        errorPresentation = .from(error)
      }
    }
  }

  func cancel() {
    guard isConverting, conversionTask != nil else { return }
    statusText = "Membatalkan…"
    conversionTask?.cancel()
  }

  private func select(_ url: URL) {
    guard !isConverting else { return }
    guard url.pathExtension.lowercased() == "acsm" else {
      errorPresentation = ErrorPresentation(
        title: "File tidak didukung",
        summary: "Pilih file dengan ekstensi .acsm.",
        detail: "File yang dipilih: \(url.path)"
      )
      return
    }
    selectedFile = url
    resultFile = nil
    statusText = "Mempersiapkan…"
    page = .convert
  }

  private func addBook(_ result: ConversionResult) {
    let coverPath = Self.saveCover(result.coverData, id: UUID())
    let record = BookRecord(
      id: UUID(),
      title: result.title,
      author: result.author,
      filePath: result.fileURL.path,
      format: result.format,
      coverPath: coverPath,
      completedAt: Date()
    )
    books.removeAll { $0.filePath == record.filePath }
    books.insert(record, at: 0)
    if let data = try? JSONEncoder().encode(books) {
      UserDefaults.standard.set(data, forKey: "bookshelf")
    }
  }

  private static func saveCover(_ data: Data?, id: UUID) -> String? {
    guard let data else { return nil }
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Lentera/covers", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let url = directory.appendingPathComponent("\(id.uuidString).jpg")
      try data.write(to: url, options: .atomic)
      return url.path
    } catch {
      return nil
    }
  }
}
