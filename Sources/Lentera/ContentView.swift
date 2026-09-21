import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @Bindable var model: ConversionModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    NavigationSplitView {
      List(selection: Binding<AppPage?>(get: { model.page }, set: { if let page = $0 { model.page = page } })) {
        Label("Konversi", systemImage: "arrow.down.doc").tag(AppPage.convert)
        Label("Rak Buku", systemImage: "books.vertical")
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
      .navigationTitle(model.page == .convert ? "Konversi" : "Rak Buku")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: model.chooseFile) { Label("Tambah File ACSM", systemImage: "plus") }
            .disabled(model.isConverting)
            .help("Pilih file ACSM (⌘O)")
        }
      }
    }
    .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted) { model.acceptDrop($0) }
    .sheet(item: $model.errorPresentation) { ErrorDetailView(error: $0) }
  }

  private var conversionPage: some View {
    ScrollView {
      VStack(spacing: 24) {
        VStack(spacing: 8) {
          Image(systemName: "arrow.down.doc")
            .font(.system(size: 38, weight: .light))
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
          Text("Dari ACSM ke buku Anda")
            .font(.title2.weight(.semibold))
          Text("Unduh buku dalam format EPUB atau PDF dari penyedia.")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        VStack(spacing: 16) {
          dropZone
          GroupBox {
            VStack(spacing: 12) {
              HStack {
                Text("Simpan ke")
                Spacer()
                Label(model.destination?.lastPathComponent ?? "Downloads", systemImage: "folder")
                  .lineLimit(1).truncationMode(.middle)
                  .help(model.destination?.path ?? "Folder Downloads")
                Button("Ubah…", action: model.chooseDestination)
                  .disabled(model.isConverting)
              }
              Divider()
              HStack {
                Text("Format hasil")
                Spacer()
                Text(model.resultFile?.pathExtension.uppercased() ?? "Otomatis (EPUB atau PDF)")
                  .foregroundStyle(.secondary)
              }
            }
            .padding(8)
          }
          status
        }
        Text("Format mengikuti buku dari penyedia. Hasil disimpan di Mac ini.")
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
      Image(systemName: model.selectedFile == nil ? "doc.badge.plus" : "doc.text")
        .font(.system(size: 30, weight: .light)).foregroundStyle(.tint)
        .accessibilityHidden(true)
      Text(model.selectedFile?.lastPathComponent ?? "Seret file ACSM ke sini")
        .font(.headline).lineLimit(2).truncationMode(.middle)
        .multilineTextAlignment(.center)
        .help(model.selectedFile?.path ?? "File dengan ekstensi .acsm")
      Button(model.selectedFile == nil ? "Pilih File…" : "Ganti File…", action: model.chooseFile)
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

  @ViewBuilder private var status: some View {
    if model.isConverting {
      VStack(spacing: 12) {
        ProgressView(model.statusText, value: model.progress)
        HStack {
          Text("\(Int(model.progress * 100))%")
            .monospacedDigit().foregroundStyle(.secondary)
          Spacer()
          Button("Batalkan", role: .cancel, action: model.cancel)
        }
      }
    } else if let result = model.resultFile {
      VStack(spacing: 12) {
        Label("Buku siap dibaca", systemImage: "checkmark.circle.fill")
          .font(.headline).foregroundStyle(.green)
        Text(result.lastPathComponent).lineLimit(2).truncationMode(.middle)
        HStack {
          Button("Tampilkan di Finder") { NSWorkspace.shared.activateFileViewerSelecting([result]) }
          Button("Konversi File Lain…", action: model.chooseFile)
            .buttonStyle(.borderedProminent)
        }
      }
      .frame(maxWidth: .infinity).padding(.top, 4)
    } else {
      HStack {
        Text(model.statusText == "Dibatalkan" ? "Konversi dibatalkan." : model.selectedFile == nil ? "Pilih file untuk memulai." : "File siap dikonversi.")
          .foregroundStyle(.secondary)
        Spacer()
        Button("Konversi", action: model.convert)
          .buttonStyle(.borderedProminent).controlSize(.large)
          .disabled(model.selectedFile == nil)
          .keyboardShortcut(.defaultAction)
      }
    }
  }

  private var bookshelfPage: some View {
    let visibleBooks = model.visibleBooks
    return VStack(spacing: 0) {
      HStack {
        Text("\(visibleBooks.count) buku").foregroundStyle(.secondary)
        Spacer()
        Picker("Filter format", selection: $model.shelfFilter) {
          ForEach(ShelfFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented).frame(width: 220)
        .labelsHidden()
        .accessibilityLabel("Filter format")
        Menu {
          Picker("Urutkan buku", selection: $model.shelfSort) {
            ForEach(ShelfSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }
        } label: {
          Image(systemName: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Urutkan buku")
        .accessibilityValue(model.shelfSort.rawValue)
        .help("Urutkan: \(model.shelfSort.rawValue)")
      }
      .padding(24)
      if visibleBooks.isEmpty {
        ContentUnavailableView {
          Label(model.books.isEmpty ? "Belum Ada Buku" : "Tidak Ada Buku yang Cocok", systemImage: "books.vertical")
        } description: {
          Text(model.books.isEmpty ? "Buku yang selesai dikonversi akan muncul di sini." : "Coba judul atau penulis lain, atau tampilkan semua buku.")
        } actions: {
          if model.books.isEmpty {
            Button("Tambah File ACSM…", action: model.chooseFile).disabled(model.isConverting)
          } else {
            Button("Tampilkan Semua") {
              model.shelfFilter = .all
              model.shelfSearch = ""
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 28)], alignment: .leading, spacing: 28) {
            ForEach(visibleBooks) { BookCard(book: $0) }
          }
          .padding(.horizontal, 24).padding(.bottom, 24)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .searchable(text: $model.shelfSearch, placement: .toolbar, prompt: "Cari judul atau penulis")
  }
}

private struct BookCard: View {
  let book: BookRecord
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Button { NSWorkspace.shared.activateFileViewerSelecting([book.fileURL]) } label: {
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
      Text(book.title).font(.headline).lineLimit(2).help(book.title)
      Text(book.author ?? "Penulis tidak tersedia").font(.callout).foregroundStyle(.secondary).lineLimit(1)
      Text(book.format.rawValue).font(.caption).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .multilineTextAlignment(.leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressFeedbackButtonStyle(reduceMotion: reduceMotion))
    .help("Tampilkan \(book.title) di Finder")
    .accessibilityLabel("Tampilkan \(book.title) di Finder")
    .contextMenu {
      Button("Tampilkan di Finder") { NSWorkspace.shared.activateFileViewerSelecting([book.fileURL]) }
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
      DisclosureGroup("Detail teknis", isExpanded: $detailExpanded) {
        ScrollView { Text(error.detail).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12) }
          .frame(height: 170).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8)).padding(.top, 10)
      }
      HStack {
        Button("Salin detail") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(error.detail, forType: .string) }
        Spacer()
        Button("Tutup") { dismiss() }.keyboardShortcut(.defaultAction)
      }
    }
    .padding(26).frame(width: 520)
  }
}
