import SwiftUI

enum ShelfLayout: String, CaseIterable {
  case shelf
  case list

  var label: String { self == .shelf ? "Shelf" : "List" }
  var symbol: String { self == .shelf ? "square.grid.2x2" : "list.bullet" }
}

/// A compact table of books, for collections that are too large to browse by cover.
struct BookshelfList: View {
  let books: [BookRecord]
  let model: ConversionModel
  let actions: BookActions
  @Binding var selection: Set<UUID>

  var body: some View {
    Table(books, selection: $selection) {
      TableColumn("Title") { book in
        HStack(spacing: 10) {
          BookCover(book: book, width: 26, height: 38, varyClothHeight: false)
            .frame(width: 26, height: 38)
            .shadow(color: .black.opacity(0.2), radius: 1, x: 1, y: 1)
            .opacity(isMissing(book) ? 0.5 : 1)
          Text(book.title)
            .lineLimit(2)
            .foregroundStyle(isMissing(book) ? .secondary : .primary)
          if isMissing(book) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
              .help("File not found")
              .accessibilityLabel("File not found")
          }
          if model.returningBookIDs.contains(book.id) {
            ProgressView().controlSize(.small)
          }
        }
        .padding(.vertical, 3)
      }
      .width(min: 200, ideal: 320)
      TableColumn("Author") { book in
        Text(book.author ?? "—").foregroundStyle(.secondary).lineLimit(1)
      }
      .width(min: 100, ideal: 160)
      TableColumn("Format") { book in
        BookTags(book: book)
      }
      .width(min: 70, ideal: 130)
      TableColumn("Added") { book in
        Text(book.completedAt.formatted(date: .abbreviated, time: .omitted))
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      .width(min: 80, ideal: 100)
    }
    .contextMenu(forSelectionType: UUID.self) { ids in
      if ids.count == 1, let book = books.first(where: { ids.contains($0.id) }) {
        BookContextMenu(book: book, model: model, actions: actions)
      }
    } primaryAction: { ids in
      for book in books where ids.contains(book.id) { model.openBook(book) }
    }
    .scrollContentBackground(.hidden)
  }

  private func isMissing(_ book: BookRecord) -> Bool {
    model.missingBookIDs.contains(book.id)
  }
}

/// Runs `action` when Space is pressed and no text field is being edited, as in Finder.
struct SpaceKeyMonitor: ViewModifier {
  let action: () -> Bool
  @State private var monitor: Any?

  func body(content: Content) -> some View {
    content
      .onAppear {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
          let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
          guard event.keyCode == 49, modifiers.subtracting(.capsLock).isEmpty,
            !(NSApp.keyWindow?.firstResponder is NSText)
          else { return event }
          return action() ? nil : event
        }
      }
      .onDisappear {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
      }
  }
}
