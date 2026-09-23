import AppKit
import SwiftUI

enum ShelfMetrics {
  static let bookWidth: CGFloat = 128
  static let coverHeight: CGFloat = 188
  static let bookSpacing: CGFloat = 26
  static let plankHeight: CGFloat = 16
  static let shelfInset: CGFloat = 18
  static let pageInset: CGFloat = 28

  static func columns(for width: CGFloat) -> Int {
    let usable = width - 2 * (pageInset + shelfInset) + bookSpacing
    return max(1, Int(usable / (bookWidth + bookSpacing)))
  }
}

extension Color {
  fileprivate static func dynamic(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    })
  }

  static let shelfWall = dynamic(
    light: NSColor(srgbRed: 0.965, green: 0.945, blue: 0.914, alpha: 1),
    dark: NSColor(srgbRed: 0.125, green: 0.110, blue: 0.098, alpha: 1))
  fileprivate static let plankTop = dynamic(
    light: NSColor(srgbRed: 0.847, green: 0.690, blue: 0.518, alpha: 1),
    dark: NSColor(srgbRed: 0.510, green: 0.373, blue: 0.263, alpha: 1))
  fileprivate static let plankFront = dynamic(
    light: NSColor(srgbRed: 0.690, green: 0.506, blue: 0.333, alpha: 1),
    dark: NSColor(srgbRed: 0.380, green: 0.267, blue: 0.180, alpha: 1))
  fileprivate static let plankEdge = dynamic(
    light: NSColor(srgbRed: 0.557, green: 0.388, blue: 0.239, alpha: 1),
    dark: NSColor(srgbRed: 0.204, green: 0.141, blue: 0.098, alpha: 1))
}

struct BookshelfGrid: View {
  let books: [BookRecord]
  let model: ConversionModel
  let onEdit: (BookRecord) -> Void

  var body: some View {
    GeometryReader { proxy in
      let columns = ShelfMetrics.columns(for: proxy.size.width)
      let rows = stride(from: 0, to: books.count, by: columns).map {
        Array(books[$0..<min($0 + columns, books.count)])
      }
      let landingOrder = books.filter { model.recentlyAddedBookIDs.contains($0.id) }.map(\.id)
      ScrollView {
        LazyVStack(spacing: 30) {
          ForEach(rows.indices, id: \.self) { index in
            ShelfRow(
              books: rows[index], landingOrder: landingOrder, model: model, onEdit: onEdit)
          }
        }
        .padding(.horizontal, ShelfMetrics.pageInset)
        .padding(.top, 8).padding(.bottom, 28)
      }
    }
  }
}

private struct ShelfRow: View {
  let books: [BookRecord]
  let landingOrder: [UUID]
  let model: ConversionModel
  let onEdit: (BookRecord) -> Void

  var body: some View {
    HStack(alignment: .top, spacing: ShelfMetrics.bookSpacing) {
      ForEach(books) { book in
        BookOnShelf(
          book: book,
          isMissing: model.missingBookIDs.contains(book.id),
          // New books land one after another, 50 ms apart.
          landingDelay: landingOrder.firstIndex(of: book.id).map { Double($0) * 0.05 },
          model: model,
          onEdit: { onEdit(book) }
        )
      }
    }
    .padding(.horizontal, ShelfMetrics.shelfInset)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(alignment: .top) {
      ShelfPlank().offset(y: ShelfMetrics.coverHeight - 3)
    }
  }
}

private struct ShelfPlank: View {
  var body: some View {
    VStack(spacing: 0) {
      LinearGradient(
        colors: [.plankTop.opacity(0.85), .plankTop], startPoint: .top, endPoint: .bottom
      )
      .frame(height: 5)
      LinearGradient(
        colors: [.plankFront, .plankEdge], startPoint: .top, endPoint: .bottom
      )
      .frame(height: ShelfMetrics.plankHeight - 5)
    }
    .clipShape(RoundedRectangle(cornerRadius: 3))
    .shadow(color: .black.opacity(0.25), radius: 5, y: 5)
    .accessibilityHidden(true)
  }
}

private struct BookOnShelf: View {
  let book: BookRecord
  let isMissing: Bool
  let landingDelay: Double?
  let model: ConversionModel
  let onEdit: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("kindleEmail") private var kindleEmail = ""
  @State private var isHovered = false

  /// A new book stays above the shelf, hidden, until `land()` drops it into place.
  private var isWaitingToLand: Bool { model.recentlyAddedBookIDs.contains(book.id) }

  private var isLifted: Bool { isHovered && !isMissing && !reduceMotion }

  var body: some View {
    Button { model.openBook(book) } label: {
      VStack(alignment: .leading, spacing: 0) {
        BookCover(book: book)
          .opacity(isMissing ? 0.5 : 1)
          .saturation(isMissing ? 0.2 : 1)
          .overlay(alignment: .topTrailing) {
            if isMissing {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
                .padding(6)
                .background(.regularMaterial, in: Circle())
                .padding(6)
            }
          }
          .shadow(color: .black.opacity(isLifted ? 0.32 : 0.22), radius: isLifted ? 10 : 4, x: 2, y: isLifted ? 8 : 3)
          .offset(y: isLifted ? -8 : 0)
          .offset(y: isWaitingToLand && !reduceMotion ? -16 : 0)
          .frame(width: ShelfMetrics.bookWidth, height: ShelfMetrics.coverHeight, alignment: .bottom)
        VStack(alignment: .leading, spacing: 3) {
          Text(book.title).font(.callout.weight(.semibold)).lineLimit(2)
          Text(book.author ?? "Author unavailable")
            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
          Text(book.format.rawValue)
            .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
            .padding(.top, 2)
        }
        .padding(.top, ShelfMetrics.plankHeight + 10)
      }
      .frame(width: ShelfMetrics.bookWidth, alignment: .leading)
      .multilineTextAlignment(.leading)
      .contentShape(Rectangle())
      .opacity(isWaitingToLand ? 0 : 1)
    }
    .buttonStyle(PressFeedbackButtonStyle(reduceMotion: reduceMotion))
    .onHover { isHovered = $0 }
    .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8), value: isLifted)
    .onAppear(perform: land)
    .help(isMissing ? "\(book.title) — file not found" : "Open \(book.title)")
    .accessibilityLabel(isMissing ? "\(book.title), file not found" : "Open \(book.title)")
    .contextMenu {
      Button("Open") { model.openBook(book) }.disabled(isMissing)
      Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([book.fileURL]) }
      Button("Send to Kindle…") { model.sendToKindle(book, address: kindleEmail) }.disabled(isMissing)
      Button("Edit Details…", action: onEdit)
      Divider()
      Button("Remove from Shelf") { model.removeBook(book.id) }
      Button("Move to Trash") { model.trashBook(book.id) }
    }
  }

  private func land() {
    guard isWaitingToLand else { return }
    withAnimation((reduceMotion ? Motion.easeOut(0.2) : Motion.settle).delay(landingDelay ?? 0)) {
      model.markBookLanded(book.id)
    }
  }
}

private struct BookCover: View {
  let book: BookRecord

  var body: some View {
    Group {
      if let url = book.coverURL, let image = NSImage(contentsOf: url) {
        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
          .frame(maxWidth: ShelfMetrics.bookWidth, maxHeight: ShelfMetrics.coverHeight)
      } else {
        ClothCover(title: book.title, author: book.author)
          .frame(
            width: ShelfMetrics.bookWidth - 6,
            height: ShelfMetrics.coverHeight - 4 - ClothCover.heightTrim(for: book.title))
      }
    }
    .overlay(alignment: .leading) {
      LinearGradient(
        stops: [
          .init(color: .black.opacity(0.35), location: 0),
          .init(color: .white.opacity(0.18), location: 0.35),
          .init(color: .black.opacity(0.12), location: 0.7),
          .init(color: .clear, location: 1),
        ],
        startPoint: .leading, endPoint: .trailing
      )
      .frame(width: 12)
    }
    .overlay {
      LinearGradient(
        colors: [.white.opacity(0.1), .clear, .black.opacity(0.08)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    .clipShape(
      UnevenRoundedRectangle(
        topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 5, topTrailingRadius: 5))
  }
}

private struct ClothCover: View {
  let title: String
  let author: String?

  private static let palette: [(Color, Color)] = [
    (Color(red: 0.55, green: 0.16, blue: 0.16), Color(red: 0.93, green: 0.80, blue: 0.55)),
    (Color(red: 0.13, green: 0.22, blue: 0.40), Color(red: 0.90, green: 0.82, blue: 0.62)),
    (Color(red: 0.16, green: 0.36, blue: 0.27), Color(red: 0.94, green: 0.86, blue: 0.66)),
    (Color(red: 0.36, green: 0.20, blue: 0.40), Color(red: 0.93, green: 0.84, blue: 0.70)),
    (Color(red: 0.72, green: 0.52, blue: 0.18), Color(red: 0.20, green: 0.14, blue: 0.08)),
    (Color(red: 0.11, green: 0.38, blue: 0.42), Color(red: 0.92, green: 0.88, blue: 0.74)),
  ]

  /// A stable FNV-1a hash, so a book keeps its look across launches.
  static func seed(for title: String) -> UInt32 {
    title.utf8.reduce(2_166_136_261) { ($0 ^ UInt32($1)) &* 16_777_619 }
  }

  static func paletteIndex(for title: String) -> Int {
    Int(seed(for: title) % UInt32(palette.count))
  }

  /// Books without a cover stand at slightly different heights, like a real shelf.
  static func heightTrim(for title: String) -> CGFloat {
    CGFloat((seed(for: title) >> 8) % 5) * 5
  }

  var body: some View {
    let (cloth, ink) = Self.palette[Self.paletteIndex(for: title)]
    ZStack {
      cloth
      RoundedRectangle(cornerRadius: 1)
        .strokeBorder(ink.opacity(0.6), lineWidth: 1)
        .padding(8)
      VStack(spacing: 8) {
        Spacer(minLength: 0)
        Text(title)
          .font(.system(size: 15, weight: .semibold, design: .serif))
          .lineLimit(4).minimumScaleFactor(0.7)
        Rectangle().fill(ink.opacity(0.6)).frame(width: 28, height: 1)
        if let author {
          Text(author)
            .font(.system(size: 10, weight: .medium, design: .serif))
            .textCase(.uppercase).tracking(0.8)
            .lineLimit(2).minimumScaleFactor(0.8)
        }
        Spacer(minLength: 0)
      }
      .foregroundStyle(ink)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 18).padding(.vertical, 20)
    }
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
