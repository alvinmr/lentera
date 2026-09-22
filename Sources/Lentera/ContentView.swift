import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @Bindable var model: ConversionModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var editingBook: BookRecord?

  var body: some View {
    NavigationSplitView {
      List(selection: Binding<AppPage?>(get: { model.page }, set: { if let page = $0 { model.page = page } })) {
        Label("Convert", systemImage: "arrow.down.doc").tag(AppPage.convert)
        Label("Bookshelf", systemImage: "books.vertical")
          .badge(model.books.count).tag(AppPage.bookshelf)
      }
      .listStyle(.sidebar)
      .navigationTitle("Lentera")
      .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
    } detail: {
      Group {
        if model.page == .convert { conversionPage } else { bookshelfPage }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(nsColor: .windowBackgroundColor))
      .navigationTitle(model.page == .convert ? "Convert" : "Bookshelf")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: model.chooseFiles) { Label("Add ACSM File", systemImage: "plus") }
            .disabled(model.isConverting)
            .help("Choose ACSM files (⌘O)")
        }
      }
    }
    .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted) { model.acceptDrop($0) }
    .sheet(item: $model.errorPresentation) { ErrorDetailView(error: $0) }
    .sheet(item: $editingBook) { book in
      BookDetailsEditor(book: book) { title, author in
        model.updateBook(book.id, title: title, author: author)
      }
    }
  }

  private var conversionPage: some View {
    ScrollView {
      VStack(spacing: 24) {
        VStack(spacing: 8) {
          Image(systemName: "arrow.down.doc")
            .font(.system(size: 38, weight: .light))
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
          Text("From ACSM to your book")
            .font(.title2.weight(.semibold))
          Text("Download your book in EPUB or PDF from the provider.")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        VStack(spacing: 16) {
          dropZone
          GroupBox {
            VStack(spacing: 12) {
              HStack {
                Text("Save to")
                Spacer()
                Label(model.destination?.lastPathComponent ?? "Downloads", systemImage: "folder")
                  .lineLimit(1).truncationMode(.middle)
                  .help(model.destination?.path ?? "Downloads folder")
                Button("Change…", action: model.chooseDestination)
                  .disabled(model.isConverting)
              }
              Divider()
              HStack {
                Text("Output format")
                Spacer()
                Text("Automatic (EPUB or PDF)")
                  .foregroundStyle(.secondary)
              }
            }
            .padding(8)
          }
          if !model.queue.isEmpty { queueList }
          status
        }
        Text("The format follows the book from the provider. Files are saved on this Mac.")
          .font(.callout).foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: 560)
      .padding(32)
      .frame(maxWidth: .infinity)
    }
  }

  private var dropZone: some View {
    VStack(spacing: 12) {
      Image(systemName: model.queue.isEmpty ? "doc.badge.plus" : "doc.on.doc")
        .font(.system(size: 30, weight: .light)).foregroundStyle(.tint)
        .accessibilityHidden(true)
      Text(model.queue.isEmpty ? "Drag one or more ACSM files here" : "Drag ACSM files to add to the queue")
        .font(.headline).lineLimit(2).truncationMode(.middle)
        .multilineTextAlignment(.center)
        .help("Files with the .acsm extension")
      Button(model.queue.isEmpty ? "Choose Files…" : "Add Files…", action: model.chooseFiles)
        .disabled(model.isConverting)
        .buttonStyle(.bordered)
    }
    .padding(24)
    .frame(maxWidth: .infinity, minHeight: 154)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(model.isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                      style: StrokeStyle(lineWidth: model.isDropTargeted ? 2 : 1, dash: model.isDropTargeted ? [] : [5, 4]))
    }
    .scaleEffect(model.isDropTargeted && !reduceMotion ? 1.01 : 1)
    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 1), value: model.isDropTargeted)
  }

  private var queueList: some View {
    VStack(spacing: 0) {
      ForEach(model.queue) { item in
        QueueRow(item: item, model: model)
        if item.id != model.queue.last?.id {
          Divider().padding(.leading, 44)
        }
      }
    }
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color(nsColor: .separatorColor))
    }
  }

  @ViewBuilder private var status: some View {
    if model.isConverting {
      VStack(spacing: 12) {
        ProgressView(value: model.overallProgress)
        HStack {
          Text(model.batchStatusText)
            .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
          Spacer()
          Button("Cancel", role: .cancel, action: model.cancel)
        }
      }
    } else if model.waitingCount > 0 {
      HStack {
        Text(model.waitingCount == 1 ? "1 file ready to convert." : "\(model.waitingCount) files ready to convert.")
          .foregroundStyle(.secondary)
        Spacer()
        Button("Convert", action: model.convert)
          .buttonStyle(.borderedProminent).controlSize(.large)
          .keyboardShortcut(.defaultAction)
      }
    } else if model.succeededCount > 0 {
      VStack(spacing: 12) {
        Label(model.succeededCount == 1 ? "1 book ready to read" : "\(model.succeededCount) books ready to read",
              systemImage: "checkmark.circle.fill")
          .font(.headline).foregroundStyle(.green)
        HStack {
          Button("Reveal All in Finder", action: revealResults)
          Button("Clear", action: model.clearFinished)
        }
      }
      .frame(maxWidth: .infinity).padding(.top, 4)
    } else if !model.queue.isEmpty {
      HStack {
        Text("No files were converted.").foregroundStyle(.secondary)
        Spacer()
        Button("Clear", action: model.clearFinished)
      }
    } else {
      Text("Choose one or more ACSM files to get started.")
        .foregroundStyle(.secondary)
    }
  }

  private func revealResults() {
    let urls = model.queue.compactMap { $0.status == .done ? $0.resultURL : nil }
    guard !urls.isEmpty else { return }
    NSWorkspace.shared.activateFileViewerSelecting(urls)
  }

  private var bookshelfPage: some View {
    let visibleBooks = model.visibleBooks
    return VStack(spacing: 0) {
      HStack {
        Text(visibleBooks.count == 1 ? "1 book" : "\(visibleBooks.count) books")
          .foregroundStyle(.secondary)
        Spacer()
        Picker("Filter format", selection: $model.shelfFilter) {
          ForEach(ShelfFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented).frame(width: 220)
        .labelsHidden()
        .accessibilityLabel("Filter by format")
        Menu {
          Picker("Sort books", selection: $model.shelfSort) {
            ForEach(ShelfSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }
        } label: {
          Image(systemName: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Sort books")
        .accessibilityValue(model.shelfSort.rawValue)
        .help("Sort: \(model.shelfSort.rawValue)")
      }
      .padding(24)
      if !model.missingBookIDs.isEmpty { missingFilesNotice }
      if visibleBooks.isEmpty {
        ContentUnavailableView {
          Label(model.books.isEmpty ? "No Books Yet" : "No Matching Books", systemImage: "books.vertical")
        } description: {
          Text(model.books.isEmpty ? "Converted books will appear here." : "Try a different title or author, or show all books.")
        } actions: {
          if model.books.isEmpty {
            Button("Add ACSM File…", action: model.chooseFiles).disabled(model.isConverting)
          } else {
            Button("Show All") {
              model.shelfFilter = .all
              model.shelfSearch = ""
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 28)], alignment: .leading, spacing: 28) {
            ForEach(visibleBooks) { book in
              BookCard(
                book: book,
                isMissing: model.missingBookIDs.contains(book.id),
                model: model,
                onEdit: { editingBook = book }
              )
            }
          }
          .padding(.horizontal, 24).padding(.bottom, 24)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .searchable(text: $model.shelfSearch, placement: .toolbar, prompt: "Search title or author")
    .task { model.refreshMissingFiles() }
  }

  private var missingFilesNotice: some View {
    HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
      Text(model.missingBookIDs.count == 1 ? "1 book file is missing." : "\(model.missingBookIDs.count) book files are missing.")
      Spacer()
      Button("Remove Missing", action: model.removeMissingBooks)
    }
    .padding(12)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10).strokeBorder(Color(nsColor: .separatorColor))
    }
    .padding(.horizontal, 24).padding(.bottom, 16)
  }
}

private struct QueueRow: View {
  let item: ConversionItem
  let model: ConversionModel

  var body: some View {
    HStack(spacing: 12) {
      icon.frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(item.fileURL.lastPathComponent)
          .lineLimit(1).truncationMode(.middle)
          .help(item.fileURL.path)
        Text(statusText)
          .font(.caption)
          .foregroundStyle(item.status == .failed ? Color.red : Color.secondary)
          .lineLimit(2)
      }
      Spacer(minLength: 8)
      if item.status == .failed, item.error != nil {
        Button("Details") { model.errorPresentation = item.error }
          .buttonStyle(.borderless)
      }
      if item.status == .done, let url = item.resultURL {
        Button {
          NSWorkspace.shared.activateFileViewerSelecting([url])
        } label: {
          Image(systemName: "folder")
        }
        .buttonStyle(.borderless)
        .help("Reveal in Finder")
        .accessibilityLabel("Reveal in Finder")
      }
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
    .contentShape(Rectangle())
    .contextMenu {
      if item.status == .done, let url = item.resultURL {
        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
      }
      Button("Remove from Queue") { model.removeItem(item.id) }
        .disabled(model.isConverting || item.status == .active)
    }
  }

  @ViewBuilder private var icon: some View {
    switch item.status {
    case .waiting:
      Image(systemName: "circle.dashed").foregroundStyle(.secondary)
    case .active:
      ProgressView().controlSize(.small)
    case .done:
      Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
    case .failed:
      Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
    case .cancelled:
      Image(systemName: "minus.circle").foregroundStyle(.secondary)
    }
  }

  private var statusText: String {
    switch item.status {
    case .waiting:
      return "Waiting"
    case .active:
      return item.message.isEmpty ? "Processing…" : "\(item.message) · \(Int(item.progress * 100))%"
    case .done:
      return "Done"
    case .failed:
      return item.error?.summary ?? "Failed"
    case .cancelled:
      return "Canceled"
    }
  }
}

private struct BookCard: View {
  let book: BookRecord
  let isMissing: Bool
  let model: ConversionModel
  let onEdit: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Button { model.openBook(book) } label: {
      VStack(alignment: .leading, spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor))
          if let url = book.coverURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().scaledToFit()
          } else {
            Image(systemName: "book.closed").font(.system(size: 40, weight: .light)).foregroundStyle(.secondary)
          }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .opacity(isMissing ? 0.55 : 1)
        .overlay(alignment: .topTrailing) {
          if isMissing {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 15))
              .foregroundStyle(.orange)
              .padding(6)
              .background(.regularMaterial, in: Circle())
              .padding(6)
          }
        }
        Text(book.title).font(.headline).lineLimit(2).help(book.title)
        Text(book.author ?? "Author unavailable").font(.callout).foregroundStyle(.secondary).lineLimit(1)
        Text(book.format.rawValue).font(.caption).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .multilineTextAlignment(.leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressFeedbackButtonStyle(reduceMotion: reduceMotion))
    .help(isMissing ? "\(book.title) — file not found" : "Open \(book.title)")
    .accessibilityLabel(isMissing ? "\(book.title), file not found" : "Open \(book.title)")
    .contextMenu {
      Button("Open") { model.openBook(book) }.disabled(isMissing)
      Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([book.fileURL]) }
      Button("Edit Details…", action: onEdit)
      Divider()
      Button("Remove from Shelf") { model.removeBook(book.id) }
      Button("Move to Trash") { model.trashBook(book.id) }
    }
  }
}

private struct BookDetailsEditor: View {
  let book: BookRecord
  let onSave: (String, String?) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var title: String
  @State private var author: String

  init(book: BookRecord, onSave: @escaping (String, String?) -> Void) {
    self.book = book
    self.onSave = onSave
    _title = State(initialValue: book.title)
    _author = State(initialValue: book.author ?? "")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Edit Details").font(.title2.weight(.semibold))
      VStack(alignment: .leading, spacing: 12) {
        TextField("Title", text: $title)
        TextField("Author", text: $author)
      }
      .textFieldStyle(.roundedBorder)
      Text("Changes apply to your bookshelf only. The book file is not modified.")
        .font(.caption).foregroundStyle(.secondary)
      HStack {
        Spacer()
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("Save") {
          onSave(title, author.isEmpty ? nil : author)
          dismiss()
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(24).frame(width: 420)
  }
}

private struct PressFeedbackButtonStyle: ButtonStyle {
  let reduceMotion: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.82 : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

private struct ErrorDetailView: View {
  let error: ErrorPresentation
  @Environment(\.dismiss) private var dismiss
  @State private var detailExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 25)).foregroundStyle(.orange)
        VStack(alignment: .leading, spacing: 7) {
          Text(error.title).font(.title2.weight(.semibold))
          Text(error.summary).foregroundStyle(.secondary).lineSpacing(3).textSelection(.enabled)
        }
      }
      DisclosureGroup("Technical details", isExpanded: $detailExpanded) {
        ScrollView { Text(error.detail).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12) }
          .frame(height: 170).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8)).padding(.top, 10)
      }
      HStack {
        Button("Copy details") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(error.detail, forType: .string) }
        Spacer()
        Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
      }
    }
    .padding(26).frame(width: 520)
  }
}
