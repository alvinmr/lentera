import SwiftUI

@main
struct LenteraApp: App {
  @State private var converter = ConversionModel()

  var body: some Scene {
    WindowGroup {
      ContentView(model: converter)
        .frame(minWidth: 780, minHeight: 560)
    }
    .defaultSize(width: 920, height: 660)
    .windowToolbarStyle(.unified)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Pilih File ACSM…") { converter.chooseFile() }
          .keyboardShortcut("o")
          .disabled(converter.isConverting)
      }
    }
  }
}
