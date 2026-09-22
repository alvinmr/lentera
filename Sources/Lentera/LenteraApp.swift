import Sparkle
import SwiftUI

@main
struct LenteraApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var converter = ConversionModel(notify: BatchNotification.post)
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
    Settings {
      SettingsView(model: converter, updater: updaterController.updater)
    }
    .commands {
      CommandGroup(replacing: .help) {
        Link(
          "Lentera Help",
          destination: URL(string: "https://github.com/alvinmr/lentera#readme")!)
        Link(
          "Release Notes",
          destination: URL(string: "https://github.com/alvinmr/lentera/releases")!)
      }
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
