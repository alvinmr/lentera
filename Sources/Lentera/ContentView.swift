import AppKit
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @Bindable var model: ConversionModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var editingBook: BookRecord?
  @State private var returningBook: BookRecord?
  @State private var quickLookURL: URL?
  @State private var hoveredBookID: UUID?
  @State private var selectedBookIDs: Set<UUID> = []
  @AppStorage("shelfLayout") private var shelfLayout = ShelfLayout.shelf
  @AppStorage("shelfCoverScale") private var coverScale = 1.0

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
      BookDetailsEditor(book: book, isMissing: model.missingBookIDs.contains(book.id)) {
        title, author, cover in
        withAnimation(Motion.easeOut(0.25)) {
          model.updateBook(book.id, title: title, author: author, cover: cover)
        }
      }
    }
    .confirmationDialog(
      "Return “\(returningBook?.title ?? "")”?", isPresented: returnDialogBinding,
      presenting: returningBook
    ) { book in
      Button("Return Loan", role: .destructive) { model.returnLoan(book.id) }
    } message: { _ in
      Text("Lentera returns the loan to the provider and moves the book file to the Trash.")
    }
    .quickLookPreview($quickLookURL)
  }

  private var returnDialogBinding: Binding<Bool> {
    Binding(get: { returningBook != nil }, set: { if !$0 { returningBook = nil } })
  }

  private var bookActions: BookActions {
    BookActions(
      edit: { editingBook = $0 },
      returnLoan: { returningBook = $0 },
      quickLook: { quickLookURL = $0.fileURL })
  }

  /// Space opens Quick Look for the hovered book on the shelf, or the selected book in the list.
  private func toggleQuickLook() -> Bool {
    guard model.page == .bookshelf, editingBook == nil else { return false }
    if quickLookURL != nil {
      quickLookURL = nil
      return true
    }
    let target: UUID? =
      shelfLayout == .shelf
      ? hoveredBookID
      : model.visibleBooks.first { selectedBookIDs.contains($0.id) }?.id
    guard let target, let book = model.books.first(where: { $0.id == target }),
      !model.missingBookIDs.contains(target)
    else { return false }
    quickLookURL = book.fileURL
    return true
  }

  private var conversionPage: some View {
    ScrollView {
      VStack(spacing: 24) {
        VStack(spacing: 8) {
          Text("From ACSM to your book")
            .font(.title2.weight(.semibold))
          Text("Download your book in EPUB or PDF from the provider.")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        VStack(spacing: 16) {
          dropZone
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
          .padding(14)
          .lenteraSurface()
          if !model.queue.isEmpty {
            queueList.transition(Motion.appear(reduceMotion: reduceMotion, anchor: .top))
          }
          rateLimitNotice
          status
        }
        .animation(Motion.easeOut(0.25), value: model.queue.map(\.id))
        Text("The provider chooses EPUB or PDF. Files are saved on this Mac.")
          .font(.callout).foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: 560)
      .padding(32)
      .frame(maxWidth: .infinity)
    }
  }

  /// Large while the queue is empty; one row once the queue is the focus of the page.
  @ViewBuilder private var dropZoneContent: some View {
    if model.queue.isEmpty {
      VStack(spacing: 12) {
        Image(systemName: "doc.badge.plus")
          .font(.system(size: 34, weight: .light)).foregroundStyle(.tint)
          .accessibilityHidden(true)
        Text("Drag one or more ACSM files here")
          .font(.headline)
          .multilineTextAlignment(.center)
          .help("Files with the .acsm extension")
        Button("Choose Files…", action: model.chooseFiles)
          .disabled(model.isConverting)
          .lenteraButton()
      }
      .padding(24)
      .frame(maxWidth: .infinity, minHeight: 170)
    } else {
      HStack(spacing: 12) {
        Image(systemName: "doc.badge.plus")
          .font(.system(size: 20, weight: .light)).foregroundStyle(.tint)
          .accessibilityHidden(true)
        Text("Drag more ACSM files here")
          .foregroundStyle(.secondary)
          .help("Files with the .acsm extension")
        Spacer()
        Button("Add Files…", action: model.chooseFiles)
          .disabled(model.isConverting)
          .lenteraButton()
      }
      .padding(.horizontal, 16).padding(.vertical, 12)
      .frame(maxWidth: .infinity)
    }
  }

  private var dropZone: some View {
    ZStack {
      dropZoneContent
        .id(model.queue.isEmpty)
        .transition(.opacity)
    }
    .animation(Motion.easeOut(0.25), value: model.queue.isEmpty)
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
        VStack(spacing: 0) {
          QueueRow(item: item, model: model)
          if item.id != model.queue.last?.id {
            Divider().padding(.leading, 44)
          }
        }
        .transition(Motion.appear(reduceMotion: reduceMotion, anchor: .top))
      }
    }
    .lenteraSurface()
  }

  /// Shown until the rate limit cooldown ends, so a quick retry does not extend the limit.
  private var rateLimitNotice: some View {
    // The context date of an explicit schedule is the next entry, so compare with `.now`.
    TimelineView(.explicit(model.rateLimitedUntil.map { [$0] } ?? [])) { _ in
      if let until = model.rateLimitedUntil, until > .now {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Image(systemName: "clock.badge.exclamationmark")
            .foregroundStyle(.orange)
            .accessibilityHidden(true)
          Text(
            "The book provider is limiting requests. Wait until \(until.formatted(date: .omitted, time: .shortened)) before you convert or retry."
          )
          .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .transition(Motion.appear(reduceMotion: reduceMotion, anchor: .top))
      }
    }
    .animation(Motion.easeOut(0.25), value: model.rateLimitedUntil)
  }

  private enum StatusPhase {
    case converting, ready, succeeded, nothingConverted, idle
  }

  private var statusPhase: StatusPhase {
    if model.isConverting { return .converting }
    if model.waitingCount > 0 { return .ready }
    if model.succeededCount > 0 { return .succeeded }
    return model.queue.isEmpty ? .idle : .nothingConverted
  }

  private var status: some View {
    ZStack {
      statusContent
        .id(statusPhase)
        .transition(Motion.appear(reduceMotion: reduceMotion))
    }
    .animation(Motion.easeOut(0.3), value: statusPhase)
  }

  @ViewBuilder private var statusContent: some View {
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
        SuccessLabel(count: model.succeededCount)
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
        if shelfLayout == .shelf {
          coverSizeSlider
            .transition(.opacity)
        }
        Picker("Filter format", selection: $model.shelfFilter) {
          ForEach(ShelfFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented).frame(width: 180)
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
        Picker("Layout", selection: $shelfLayout) {
          ForEach(ShelfLayout.allCases, id: \.self) { layout in
            Label(layout.label, systemImage: layout.symbol).tag(layout)
          }
        }
        .pickerStyle(.segmented)
        .labelStyle(.iconOnly)
        .labelsHidden()
        .fixedSize()
        .help("Show books on a shelf or in a list")
      }
      .animation(Motion.easeOut(0.2), value: shelfLayout)
      .padding(24)
      if !model.missingBookIDs.isEmpty {
        missingFilesNotice.transition(
          reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
      }
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
      } else if shelfLayout == .shelf {
        BookshelfGrid(
          books: visibleBooks, model: model, actions: bookActions, hoveredBookID: $hoveredBookID
        )
        .environment(\.shelfMetrics, ShelfMetrics(scale: coverScale))
      } else {
        BookshelfList(
          books: visibleBooks, model: model, actions: bookActions, selection: $selectedBookIDs)
      }
    }
    .modifier(SpaceKeyMonitor(action: toggleQuickLook))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color.shelfWall)
    .searchable(text: $model.shelfSearch, placement: .toolbar, prompt: "Search title or author")
    .task { model.refreshMissingFiles() }
  }

  private var coverSizeSlider: some View {
    HStack(spacing: 6) {
      Image(systemName: "book.closed").imageScale(.small)
      Slider(value: $coverScale, in: ShelfMetrics.scaleRange)
        .controlSize(.small)
        .frame(width: 90)
      Image(systemName: "book.closed").imageScale(.large)
    }
    .foregroundStyle(.secondary)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Cover size")
    .help("Cover size")
  }

  private var missingFilesNotice: some View {
    HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
      Text(model.missingBookIDs.count == 1 ? "1 book file is missing." : "\(model.missingBookIDs.count) book files are missing.")
      Spacer()
      Button("Remove Missing") {
        withAnimation(Motion.easeOut(0.2)) { model.removeMissingBooks() }
      }
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
        HStack(spacing: 6) {
          Text(item.displayName)
            .lineLimit(1).truncationMode(.middle)
          if let format = item.info?.format {
            Tag(text: format.rawValue)
          }
          if item.info?.isLoan == true {
            Tag(text: "Loan")
          }
        }
        .help(item.fileURL.path)
        if let author = item.info?.author {
          Text(author)
            .font(.caption).foregroundStyle(.secondary)
            .lineLimit(1)
        }
        // Redraws at the download deadline, so the row turns orange without other changes.
        // The context date of an explicit schedule is the next entry, not the current time.
        TimelineView(.explicit(item.info?.expiration.map { [$0] } ?? [])) { _ in
          Text(statusText(at: .now))
            .font(.caption)
            .foregroundStyle(statusColor(at: .now))
            .lineLimit(2)
        }
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

  private var icon: some View {
    ZStack {
      if item.isActive {
        ProgressView().controlSize(.small).transition(.opacity)
      } else {
        Image(systemName: symbol.name)
          .foregroundStyle(symbol.color)
          .contentTransition(.symbolEffect(.replace))
          .transition(.opacity)
      }
    }
    .animation(Motion.easeOut(0.15), value: item.isActive ? "spinner" : symbol.name)
  }

  private var symbol: (name: String, color: Color) {
    switch item.state {
    case .waiting, .active: ("circle.dashed", .secondary)
    case .done: ("checkmark.circle.fill", .green)
    case .failed: ("xmark.octagon.fill", .red)
    case .cancelled: ("minus.circle", .secondary)
    }
  }

  private func isExpired(at now: Date) -> Bool {
    item.isWaiting && item.info?.isExpired(at: now) == true
  }

  private func statusColor(at now: Date) -> Color {
    if item.isFailed { return .red }
    return isExpired(at: now) ? .orange : .secondary
  }

  private func statusText(at now: Date) -> String {
    switch item.state {
    case .waiting:
      guard let expiration = item.info?.expiration else { return "Waiting" }
      let date = expiration.formatted(date: .abbreviated, time: .omitted)
      return isExpired(at: now)
        ? "License expired on \(date). Download a new ACSM if this fails."
        : "Waiting · Download before \(date)"
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

private struct SuccessLabel: View {
  let count: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var bounce = false

  var body: some View {
    Label {
      Text(count == 1 ? "1 book ready to read" : "\(count) books ready to read")
    } icon: {
      Image(systemName: "checkmark.circle.fill").symbolEffect(.bounce, value: bounce)
    }
    .font(.headline).foregroundStyle(.green)
    .onAppear { if !reduceMotion { bounce.toggle() } }
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
