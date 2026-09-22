import Sparkle
import SwiftUI

struct SettingsView: View {
  @Bindable var model: ConversionModel
  let updater: SPUUpdater
  @AppStorage("notifyOnCompletion") private var notifyOnCompletion = true

  var body: some View {
    Form {
      Section("Output") {
        HStack {
          Text("Save to")
          Spacer()
          Label(model.destination?.lastPathComponent ?? "Downloads", systemImage: "folder")
            .lineLimit(1).truncationMode(.middle)
            .foregroundStyle(.secondary)
            .help(model.destination?.path ?? "Downloads folder")
          Button("Change…", action: model.chooseDestination)
        }
      }
      Section("Updates") {
        Toggle(
          "Check for updates automatically",
          isOn: Binding(
            get: { updater.automaticallyChecksForUpdates },
            set: { updater.automaticallyChecksForUpdates = $0 }))
      }
      Section("Notifications") {
        Toggle("Notify when a conversion batch finishes", isOn: $notifyOnCompletion)
      }
    }
    .formStyle(.grouped)
    .frame(width: 460)
  }
}
