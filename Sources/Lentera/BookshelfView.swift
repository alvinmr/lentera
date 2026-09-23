import AppKit
import SwiftUI

/// Shelf sizes at a cover scale the viewer picks with the size slider.
struct ShelfMetrics: Equatable {
  static let scaleRange: ClosedRange<Double> = 0.75...1.4
  static let standard = ShelfMetrics(scale: 1)

  var scale: CGFloat
  var bookWidth: CGFloat { 128 * scale }
  var coverHeight: CGFloat { 188 * scale }
  var bookSpacing: CGFloat { 26 * scale }
  let plankHeight: CGFloat = 16
  let shelfInset: CGFloat = 18
  let pageInset: CGFloat = 28

  func columns(for width: CGFloat) -> Int {
    let usable = width - 2 * (pageInset + shelfInset) + bookSpacing
    return max(1, Int(usable / (bookWidth + bookSpacing)))
  }
}

extension EnvironmentValues {
  @Entry var shelfMetrics = ShelfMetrics.standard
}

/// What a book on the shelf or in the list can ask the page to do.
struct BookActions {
  var edit: (BookRecord) -> Void = { _ in }
  /// Asks for confirmation before the loan goes back to the provider.
  var returnLoan: (BookRecord) -> Void = { _ in }
  var quickLook: (BookRecord) -> Void = { _ in }
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
  let actions: BookActions
  @Binding var hoveredBookID: UUID?
  @Environment(\.shelfMetrics) private var metrics

  var body: some View {
    GeometryReader { proxy in
      let columns = metrics.columns(for: proxy.size.width)
      let rows = stride(from: 0, to: books.count, by: columns).map {
        Array(books[$0..<min($0 + columns, books.count)])
      }
      let landingOrder = books.filter { model.recentlyAddedBookIDs.contains($0.id) }.map(\.id)
      ScrollView {
        LazyVStack(spacing: 30) {
          ForEach(rows.indices, id: \.self) { index in
            ShelfRow(
              books: rows[index], landingOrder: landingOrder, model: model, actions: actions,
              hoveredBookID: $hoveredBookID)
          }
        }
        .padding(.horizontal, metrics.pageInset)
        .padding(.top, 8).padding(.bottom, 28)
      }
    }
  }
}

private struct ShelfRow: View {
  let books: [BookRecord]
  let landingOrder: [UUID]
  let model: ConversionModel
  let actions: BookActions
  @Binding var hoveredBookID: UUID?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.shelfMetrics) private var metrics

  var body: some View {
    HStack(alignment: .top, spacing: metrics.bookSpacing) {
      ForEach(books) { book in
        BookOnShelf(
          book: book,
          isMissing: model.missingBookIDs.contains(book.id),
          // New books land one after another, 50 ms apart.
          landingDelay: landingOrder.firstIndex(of: book.id).map { Double($0) * 0.05 },
          model: model,
          actions: actions,
          onHover: { hovering in
            if hovering {
              hoveredBookID = book.id
            } else if hoveredBookID == book.id {
              hoveredBookID = nil
            }
          }
        )
        .transition(Motion.appear(reduceMotion: reduceMotion, scale: 0.95))
      }
    }
    .padding(.horizontal, metrics.shelfInset)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(alignment: .top) {
      ShelfPlank().offset(y: metrics.coverHeight - 3)
    }
  }
}

private struct ShelfPlank: View {
  @Environment(\.shelfMetrics) private var metrics

  var body: some View {
    VStack(spacing: 0) {
      LinearGradient(
        colors: [.plankTop.opacity(0.85), .plankTop], startPoint: .top, endPoint: .bottom
      )
      .frame(height: 5)
      LinearGradient(
        colors: [.plankFront, .plankEdge], startPoint: .top, endPoint: .bottom
      )
      .frame(height: metrics.plankHeight - 5)
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
  let actions: BookActions
  let onHover: (Bool) -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.shelfMetrics) private var metrics
  @State private var isHovered = false

  /// A new book stays above the shelf, hidden, until `land()` drops it into place.
  private var isWaitingToLand: Bool { model.recentlyAddedBookIDs.contains(book.id) }

  private var isReturning: Bool { model.returningBookIDs.contains(book.id) }

  private var isLifted: Bool { isHovered && !isMissing && !reduceMotion }

  var body: some View {
    Button { model.openBook(book) } label: {
      VStack(alignment: .leading, spacing: 0) {
        BookCover(book: book, width: metrics.bookWidth, height: metrics.coverHeight)
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
          .overlay {
            if isReturning {
              ProgressView()
                .padding(10)
                .background(.regularMaterial, in: Circle())
                .transition(.opacity)
            }
          }
          .shadow(color: .black.opacity(isLifted ? 0.28 : 0.22), radius: isLifted ? 6 : 4, x: 2, y: isLifted ? 5 : 3)
          .offset(y: isLifted ? -3 : 0)
          .offset(y: isWaitingToLand && !reduceMotion ? -16 : 0)
          .frame(width: metrics.bookWidth, height: metrics.coverHeight, alignment: .bottom)
        VStack(alignment: .leading, spacing: 3) {
          // Two lines are always reserved, so the author and tags line up across a shelf.
          Text(book.title).font(.callout.weight(.semibold))
            .lineLimit(2, reservesSpace: true)
          Text(book.author ?? BookMetadata.unknownAuthor)
            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
          BookTags(book: book).padding(.top, 2)
        }
        .padding(.top, metrics.plankHeight + 10)
      }
      .frame(width: metrics.bookWidth, alignment: .leading)
      .multilineTextAlignment(.leading)
      .contentShape(Rectangle())
      .opacity(isWaitingToLand ? 0 : 1)
    }
    .buttonStyle(PressFeedbackButtonStyle(reduceMotion: reduceMotion))
    .onHover {
      isHovered = $0
      onHover($0)
    }
    .animation(Motion.hover, value: isLifted)
    .animation(Motion.easeOut(0.2), value: isReturning)
    .onAppear(perform: land)
    .help(isMissing ? "\(book.title) — file not found" : "Open \(book.title)")
    .accessibilityLabel(isMissing ? "\(book.title), file not found" : "Open \(book.title)")
    .contextMenu {
      BookContextMenu(book: book, model: model, actions: actions)
    }
  }

  private func land() {
    guard isWaitingToLand else { return }
    withAnimation((reduceMotion ? Motion.easeOut(0.2) : Motion.settle).delay(landingDelay ?? 0)) {
      model.markBookLanded(book.id)
    }
  }
}

/// The format, and for a loan, when it ends.
struct BookTags: View {
  let book: BookRecord

  var body: some View {
    // Redraws when the loan ends, so the tag turns orange on time. The context date of an
    // explicit schedule is the next entry, not the current time, so compare with `.now`.
    TimelineView(.explicit(book.loanExpiresAt.map { [$0] } ?? [])) { _ in
      let ended = book.isLoanExpired(at: .now)
      // Narrow shelf columns get an icon in place of the loan text.
      ViewThatFits(in: .horizontal) {
        tags(compact: false, ended: ended)
        tags(compact: true, ended: ended)
      }
      .help(loanHelp(ended: ended))
    }
  }

  private func tags(compact: Bool, ended: Bool) -> some View {
    HStack(spacing: 4) {
      Tag(text: book.format.rawValue)
      if book.isLoan {
        if compact {
          Tag(symbol: ended ? "exclamationmark.circle" : "clock", tint: ended ? .orange : nil)
        } else if ended {
          Tag(text: "Loan ended", tint: .orange)
        } else if let end = book.loanExpiresAt {
          Tag(text: "Loan · \(end.formatted(.dateTime.day().month(.abbreviated)))")
        } else {
          Tag(text: "Loan")
        }
      }
    }
    .fixedSize()
  }

  private func loanHelp(ended: Bool) -> String {
    guard book.isLoan else { return "" }
    guard let end = book.loanExpiresAt else { return "Library loan" }
    let date = end.formatted(date: .long, time: .shortened)
    return ended ? "The loan ended on \(date)" : "Library loan until \(date)"
  }
}

struct BookContextMenu: View {
  let book: BookRecord
  let model: ConversionModel
  let actions: BookActions
  @AppStorage("kindleEmail") private var kindleEmail = ""

  private var isMissing: Bool { model.missingBookIDs.contains(book.id) }

  var body: some View {
    Button("Open") { model.openBook(book) }.disabled(isMissing)
    Button("Quick Look") { actions.quickLook(book) }.disabled(isMissing)
    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([book.fileURL]) }
    Button("Send to Kindle…") { model.sendToKindle(book, address: kindleEmail) }
      .disabled(isMissing)
    Button("Edit Details…") { actions.edit(book) }
    Divider()
    if book.isLoan {
      Button("Return Loan…") { actions.returnLoan(book) }
        .disabled(model.returningBookIDs.contains(book.id))
    }
    Button("Remove from Shelf") {
      withAnimation(Motion.easeOut(0.2)) { model.removeBook(book.id) }
    }
    Button("Move to Trash") {
      withAnimation(Motion.easeOut(0.2)) { model.trashBook(book.id) }
    }
  }
}

/// Loads a book's cover through `CoverCache`, so the shelf never decodes images while it renders.
struct BookCover: View {
  let book: BookRecord
  var width = ShelfMetrics.standard.bookWidth
  var height = ShelfMetrics.standard.coverHeight
  var varyClothHeight = true
  @State private var loaded: (path: String, image: NSImage?)?

  private var image: NSImage? {
    guard let path = book.coverPath else { return nil }
    if let loaded, loaded.path == path { return loaded.image }
    return CoverCache.cached(path)
  }

  private var isLoading: Bool {
    guard let path = book.coverPath else { return false }
    return loaded?.path != path && CoverCache.cached(path) == nil
  }

  var body: some View {
    Group {
      if isLoading {
        Color.clear.frame(width: width - 6, height: height - 4)
      } else {
        CoverArt(
          image: image, title: book.title, author: book.author, width: width, height: height,
          varyClothHeight: varyClothHeight)
      }
    }
    .task(id: book.coverPath) {
      guard let path = book.coverPath, CoverCache.cached(path) == nil else { return }
      let image = await CoverCache.image(for: path)
      loaded = (path, image)
    }
  }
}

/// A cover image with a book spine, or a cloth cover when the book has no image.
struct CoverArt: View {
  let image: NSImage?
  let title: String
  let author: String?
  var width = ShelfMetrics.standard.bookWidth
  var height = ShelfMetrics.standard.coverHeight
  /// On the shelf, cloth covers stand at slightly different heights.
  var varyClothHeight = true

  private var scale: CGFloat { height / ShelfMetrics.standard.coverHeight }

  var body: some View {
    Group {
      if let image {
        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
          .frame(maxWidth: width, maxHeight: height)
      } else {
        ClothCover(title: title, author: author, scale: scale)
          .frame(
            width: width - 6 * scale,
            height: height - (4 + (varyClothHeight ? ClothCover.heightTrim(for: title) : 0)) * scale)
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
      .frame(width: 12 * scale)
    }
    .overlay {
      LinearGradient(
        colors: [.white.opacity(0.1), .clear, .black.opacity(0.08)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    .clipShape(
      UnevenRoundedRectangle(
        topLeadingRadius: 2 * scale, bottomLeadingRadius: 2 * scale,
        bottomTrailingRadius: 5 * scale, topTrailingRadius: 5 * scale))
  }
}

private struct ClothCover: View {
  let title: String
  let author: String?
  var scale: CGFloat = 1

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
        .padding(8 * scale)
      VStack(spacing: 8 * scale) {
        Spacer(minLength: 0)
        Text(title)
          .font(.system(size: 15 * scale, weight: .semibold, design: .serif))
          .lineLimit(4).minimumScaleFactor(0.7)
        Rectangle().fill(ink.opacity(0.6)).frame(width: 28 * scale, height: 1)
        if let author {
          Text(author)
            .font(.system(size: 10 * scale, weight: .medium, design: .serif))
            .textCase(.uppercase).tracking(0.8)
            .lineLimit(2).minimumScaleFactor(0.8)
        }
        Spacer(minLength: 0)
      }
      .foregroundStyle(ink)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 18 * scale).padding(.vertical, 20 * scale)
    }
  }
}

private struct PressFeedbackButtonStyle: ButtonStyle {
  let reduceMotion: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.82 : 1)
      .animation(Motion.press, value: configuration.isPressed)
  }
}
