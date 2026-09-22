import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var pendingURLs: [URL] = []
  private var openFiles: (([URL]) -> Void)?

  func application(_ application: NSApplication, open urls: [URL]) {
    enqueue(urls)
  }

  func application(_ sender: NSApplication, openFiles filenames: [String]) {
    enqueue(filenames.map { URL(fileURLWithPath: $0) })
    sender.reply(toOpenOrPrint: .success)
  }

  private func enqueue(_ urls: [URL]) {
    guard !urls.isEmpty else { return }
    if let openFiles {
      openFiles(urls)
    } else {
      pendingURLs.append(contentsOf: urls)
    }
  }

  func connect(_ handler: @escaping ([URL]) -> Void) {
    openFiles = handler
    guard !pendingURLs.isEmpty else { return }
    let urls = pendingURLs
    pendingURLs.removeAll()
    handler(urls)
  }
}
