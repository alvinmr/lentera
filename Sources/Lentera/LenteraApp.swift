import Sparkle
import SwiftUI

@main
struct LenteraApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var converter = ConversionModel()
  private let updaterController: SPUStandardUpdaterController

  init() {
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
  }

  var body: some Scene {
    WindowGroup {
      ContentView(model: converter)
        .frame(minWidth: 780, minHeight: 560)
        .onAppear { appDelegate.connect { converter.addFiles($0) } }
    }
    .defaultSize(width: 920, height: 660)
    .windowToolbarStyle(.unified)
    .commands {
      CommandGroup(after: .appInfo) {
        CheckForUpdatesView(updater: updaterController.updater)
      }
      CommandGroup(replacing: .newItem) {
        Button("Choose ACSM File…") { converter.chooseFiles() }
          .keyboardShortcut("o")
          .disabled(converter.isConverting)
      }
    }
  }
}
