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
          VStack(spacing: 12) {
            HStack {
              Text("Save to")
              Spacer()
              Label(model.destination?.lastPathComponent ?? "Downloads", systemImage: "folder")
                .lineLimit(1).truncationMode(.middle)
                .help(model.destination?.path ?? "Downloads folder")
              Button("Change…", action: model.chooseDestination)
                .disabled(model.isConverting)
                .lenteraButton()
            }
            Divider()
            HStack {
              Text("Output format")
              Spacer()
              Text("Automatic (EPUB or PDF)")
                .foregroundStyle(.secondary)
            }
          }
          .padding(14)
          .lenteraSurface()
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
        .lenteraButton()
    }
    .padding(24)
    .frame(maxWidth: .infinity, minHeight: 154)
    .lenteraSurface()
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
    .lenteraSurface()
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
            .lenteraButton()
        }
      }
    } else if model.waitingCount > 0 {
      HStack {
        Text(model.waitingCount == 1 ? "1 file ready to convert." : "\(model.waitingCount) files ready to convert.")
          .foregroundStyle(.secondary)
        Spacer()
        Button("Convert", action: model.convert)
          .lenteraProminentButton().controlSize(.large)
          .keyboardShortcut(.defaultAction)
      }
    } else if model.succeededCount > 0 {
      VStack(spacing: 12) {
        Label(model.succeededCount == 1 ? "1 book ready to read" : "\(model.succeededCount) books ready to read",
              systemImage: "checkmark.circle.fill")
          .font(.headline).foregroundStyle(.green)
        HStack {
          Button("Reveal All in Finder", action: revealResults)
            .lenteraButton()
          Button("Clear", action: model.clearFinished)
            .lenteraButton()
        }
      }
      .frame(maxWidth: .infinity).padding(.top, 4)
    } else if !model.queue.isEmpty {
      HStack {
        Text("No files were converted.").foregroundStyle(.secondary)
        Spacer()
        Button("Clear", action: model.clearFinished)
          .lenteraButton()
      }
    } else {
      Text("Choose one or more ACSM files to get started.")
        .foregroundStyle(.secondary)
    }
  }

  private func revealResults() {
    let urls = model.queue.compactMap(\.resultURL)
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
        BookshelfGrid(books: visibleBooks, model: model, onEdit: { editingBook = $0 })
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color.shelfWall)
    .searchable(text: $model.shelfSearch, placement: .toolbar, prompt: "Search title or author")
    .task { model.refreshMissingFiles() }
  }

  private var missingFilesNotice: some View {
    HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
      Text(model.missingBookIDs.count == 1 ? "1 book file is missing." : "\(model.missingBookIDs.count) book files are missing.")
      Spacer()
      Button("Remove Missing", action: model.removeMissingBooks)
        .lenteraButton()
    }
    .padding(12)
    .lenteraSurface(cornerRadius: 10)
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
          .foregroundStyle(item.isFailed ? Color.red : Color.secondary)
          .lineLimit(2)
      }
      Spacer(minLength: 8)
      if let failure = item.failure {
        Button("Details") { model.errorPresentation = failure }
          .buttonStyle(.borderless)
      }
      if item.canRetry {
        Button {
          model.retryItem(item.id)
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.borderless)
        .help("Retry")
        .accessibilityLabel("Retry")
        .disabled(model.isConverting)
      }
      if let url = item.resultURL {
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
      if let url = item.resultURL {
        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
      }
      if item.canRetry {
        Button("Retry") { model.retryItem(item.id) }
          .disabled(model.isConverting)
      }
      Button("Remove from Queue") { model.removeItem(item.id) }
        .disabled(model.isConverting || item.isActive)
    }
  }

  @ViewBuilder private var icon: some View {
    switch item.state {
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
    switch item.state {
    case .waiting:
      return "Waiting"
    case .active(let progress, let message):
      return message.isEmpty ? "Processing…" : "\(message) · \(Int(progress * 100))%"
    case .done:
      return "Done"
    case .failed(let error):
      return error.summary
    case .cancelled:
      return "Canceled"
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
          .lenteraButton()
          .keyboardShortcut(.cancelAction)
        Button("Save") {
          onSave(title, author.isEmpty ? nil : author)
          dismiss()
        }
        .lenteraProminentButton()
        .keyboardShortcut(.defaultAction)
        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(24).frame(width: 420)
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
          .frame(height: 170).lenteraSurface(cornerRadius: 8).padding(.top, 10)
      }
      HStack {
        Button("Copy details") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(error.detail, forType: .string) }
          .lenteraButton()
        Spacer()
        Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
          .lenteraProminentButton()
      }
    }
    .padding(26).frame(width: 520)
  }
}
