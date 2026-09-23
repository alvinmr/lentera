import Sparkle
import SwiftUI

struct SettingsView: View {
  @Bindable var model: ConversionModel
  let updater: SPUUpdater
  @AppStorage("notifyOnCompletion") private var notifyOnCompletion = true
  @AppStorage("kindleEmail") private var kindleEmail = ""

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
      Section {
        TextField("Kindle email", text: $kindleEmail, prompt: Text("name@kindle.com"))
      } header: {
        Text("Send to Kindle")
      } footer: {
        Text("Add the email address of your Mail account to the Approved Personal Document E-mail List on Amazon.")
          .font(.caption).foregroundStyle(.secondary)
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
