import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BookDetailsEditor: View {
  let book: BookRecord
  let isMissing: Bool
  let onSave: (String, String?, CoverChange) -> Void
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var title: String
  @State private var author: String
  @State private var cover: CoverChange = .keep
  @State private var coverImage: NSImage?
  @State private var isDropTargeted = false
  @State private var isRestoring = false
  @FocusState private var focusedField: Field?

  private enum Field { case title, author }

  private static let coverWidth: CGFloat = 150
  private static let coverHeight: CGFloat = 220

  init(book: BookRecord, isMissing: Bool, onSave: @escaping (String, String?, CoverChange) -> Void) {
    self.book = book
    self.isMissing = isMissing
    self.onSave = onSave
    _title = State(initialValue: book.title)
    _author = State(initialValue: book.author ?? "")
    _coverImage = State(initialValue: book.coverPath.flatMap(CoverCache.cached))
  }

  private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

  private var hasChanges: Bool {
    trimmedTitle != book.title
      || author.trimmingCharacters(in: .whitespacesAndNewlines) != (book.author ?? "")
      || cover != .keep
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 0) {
        coverPanel
        fields
      }
      Divider()
      footer
    }
    .frame(width: 580)
    .task {
      guard coverImage == nil, let path = book.coverPath else { return }
      coverImage = await CoverCache.image(for: path)
    }
  }

  private var coverPanel: some View {
    VStack(spacing: 14) {
      CoverArt(
        image: coverImage, title: previewTitle, author: previewAuthor,
        width: Self.coverWidth, height: Self.coverHeight, varyClothHeight: false
      )
      .shadow(color: .black.opacity(0.3), radius: 10, x: 2, y: 6)
      .frame(width: Self.coverWidth, height: Self.coverHeight, alignment: .bottom)
      .overlay {
        if isDropTargeted {
          RoundedRectangle(cornerRadius: 6)
            .strokeBorder(Color.accentColor, lineWidth: 3)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .transition(.opacity)
        }
      }
      .scaleEffect(isDropTargeted && !reduceMotion ? 1.03 : 1)
      .animation(Motion.easeOut(0.2), value: isDropTargeted)
      .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted, perform: acceptDrop)
      .accessibilityLabel("Cover")
      .help("Drop an image here to use it as the cover")

      HStack(spacing: 6) {
        Button("Change…", action: chooseImage)
          .lenteraButton()
        Menu {
          Button("Use Cover from Book", action: restoreCover)
            .disabled(isMissing)
          Button("Use Plain Cover") { setCover(.remove, image: nil) }
            .disabled(coverImage == nil)
        } label: {
          Label("More cover options", systemImage: "ellipsis.circle")
            .labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More cover options")
      }
      .controlSize(.small)
    }
    .padding(.vertical, 28)
    .frame(width: 220)
    .frame(maxHeight: .infinity)
    .background { backdrop }
    .clipped()
  }

  /// The cover, blurred behind the panel, tints the editor with the book's colors.
  @ViewBuilder private var backdrop: some View {
    if let coverImage {
      Image(nsImage: coverImage)
        .resizable().aspectRatio(contentMode: .fill)
        .blur(radius: 40)
        .opacity(0.45)
        .overlay(.background.opacity(0.35))
        .accessibilityHidden(true)
    } else {
      Color.shelfWall
    }
  }

  private var fields: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Edit Details")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase).tracking(0.6)

      VStack(alignment: .leading, spacing: 14) {
        DetailsField(label: "Title", isFocused: focusedField == .title) {
          TextField("Title", text: $title, prompt: Text("Book title"), axis: .vertical)
            .font(.title3.weight(.semibold))
            .lineLimit(1...3)
            .focused($focusedField, equals: .title)
        }
        DetailsField(label: "Author", isFocused: focusedField == .author) {
          TextField("Author", text: $author, prompt: Text("Unknown author"))
            .focused($focusedField, equals: .author)
        }
      }

      Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
        infoRow("Format", book.format.rawValue)
        if let size = fileSize { infoRow("Size", size) }
        infoRow("Added", book.completedAt.formatted(date: .long, time: .shortened))
        GridRow {
          Text("File").foregroundStyle(.secondary)
          HStack(spacing: 4) {
            Text(isMissing ? "Not found" : fileName)
              .foregroundStyle(isMissing ? .orange : .primary)
              .lineLimit(1).truncationMode(.middle)
              .help(book.filePath)
            if !isMissing {
              Button {
                NSWorkspace.shared.activateFileViewerSelecting([book.fileURL])
              } label: {
                Image(systemName: "arrow.right.circle.fill")
              }
              .buttonStyle(.borderless)
              .foregroundStyle(.secondary)
              .help("Reveal in Finder")
              .accessibilityLabel("Reveal in Finder")
            }
          }
        }
      }
      .font(.callout)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))

      Text("Changes apply to your bookshelf only. The book file is not modified.")
        .font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(24)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var footer: some View {
    HStack {
      Button(action: restoreOriginal) {
        if isRestoring {
          ProgressView().controlSize(.small)
        } else {
          Text("Restore Original")
        }
      }
      .lenteraButton()
      .disabled(isMissing || isRestoring)
      .help("Read the title, author, and cover from the book file again")
      Spacer()
      Button("Cancel", role: .cancel) { dismiss() }
        .lenteraButton()
        .keyboardShortcut(.cancelAction)
      Button("Save") {
        onSave(trimmedTitle, author.isEmpty ? nil : author, cover)
        dismiss()
      }
      .lenteraProminentButton()
      .keyboardShortcut(.defaultAction)
      .disabled(trimmedTitle.isEmpty || !hasChanges)
    }
    .padding(.horizontal, 20).padding(.vertical, 14)
  }

  private var previewTitle: String { trimmedTitle.isEmpty ? book.title : trimmedTitle }

  private var previewAuthor: String? {
    let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// Older conversions kept line breaks from the title in the file name.
  private var fileName: String {
    book.fileURL.lastPathComponent.components(separatedBy: .newlines).joined(separator: " ")
  }

  private var fileSize: String? {
    guard !isMissing,
      let bytes = try? book.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
    else { return nil }
    return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
  }

  private func infoRow(_ label: String, _ value: String) -> some View {
    GridRow {
      Text(label).foregroundStyle(.secondary)
      Text(value).textSelection(.enabled)
    }
  }

  private func setCover(_ change: CoverChange, image: NSImage?) {
    withAnimation(Motion.easeOut(0.25)) {
      cover = change
      coverImage = image
    }
  }

  private func useImageData(_ data: Data) {
    guard let image = NSImage(data: data) else { return }
    setCover(.replace(data), image: image)
  }

  private func chooseImage() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = false
    panel.prompt = "Use as Cover"
    if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
      useImageData(data)
    }
  }

  private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first else { return false }
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
      _ = provider.loadObject(ofClass: URL.self) { url, _ in
        guard let url, let data = try? Data(contentsOf: url) else { return }
        Task { @MainActor in useImageData(data) }
      }
      return true
    }
    _ = provider.loadDataRepresentation(for: .image) { data, _ in
      guard let data else { return }
      Task { @MainActor in useImageData(data) }
    }
    return true
  }

  private func originalMetadata() async -> BookMetadata {
    await BookMetadata.read(from: book.fileURL, fallbackTitle: book.fileURL.deletingPathExtension().lastPathComponent)
  }

  private func apply(originalCover data: Data?) {
    if let data, let image = NSImage(data: data) {
      setCover(.replace(data), image: image)
    } else {
      setCover(.remove, image: nil)
    }
  }

  private func restoreCover() {
    Task {
      apply(originalCover: await originalMetadata().coverData)
    }
  }

  private func restoreOriginal() {
    isRestoring = true
    Task {
      let metadata = await originalMetadata()
      title = metadata.title
      author = metadata.author == BookMetadata.unknownAuthor ? "" : metadata.author
      apply(originalCover: metadata.coverData)
      isRestoring = false
    }
  }
}

/// A label above a soft, rounded field that lights up while it has focus.
private struct DetailsField<Content: View>: View {
  let label: String
  let isFocused: Bool
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(label)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
      content
        .textFieldStyle(.plain)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isFocused ? Color.accentColor : .clear, lineWidth: 2)
        }
        .animation(Motion.hover, value: isFocused)
    }
  }
}
