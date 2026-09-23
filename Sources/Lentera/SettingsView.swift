import Sparkle
import SwiftUI
import UniformTypeIdentifiers

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
      ActivationSection(isConverting: model.isConverting)
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

private struct ActivationSection: View {
  let isConverting: Bool
  @State private var account: AdobeActivation.Account?
  @State private var activatedOn: Date?
  @State private var isWorking = false
  @State private var pendingImport: URL?
  @State private var confirmReset = false
  @State private var message: (title: String, body: String)?

  var body: some View {
    Section {
      LabeledContent("Status") {
        HStack(spacing: 6) {
          Image(systemName: account == nil ? "circle.dashed" : "checkmark.seal.fill")
            .foregroundStyle(account == nil ? Color.secondary : Color.green)
          Text(statusText).foregroundStyle(.secondary)
        }
      }
      HStack {
        Button("Export…", action: export)
          .disabled(account == nil)
        Button("Import…", action: chooseImport)
        Spacer()
        Button("Reset…", role: .destructive) { confirmReset = true }
          .disabled(account == nil)
      }
      .disabled(isConverting || isWorking)
    } header: {
      Text("Adobe Activation")
    } footer: {
      Text("Export the activation before you move to a new Mac, then import it there. The backup holds your device keys, so keep it private. When you import or reset, the previous activation goes to the Trash.")
        .font(.caption).foregroundStyle(.secondary)
    }
    .onAppear(perform: refresh)
    .confirmationDialog(
      "Replace the activation on this Mac?", isPresented: importBinding, presenting: pendingImport
    ) { url in
      Button("Import") { runImport(url) }
    } message: { _ in
      Text("Lentera uses the imported activation for new conversions. Books you already converted are not affected.")
    }
    .confirmationDialog("Reset the Adobe activation?", isPresented: $confirmReset) {
      Button("Reset", role: .destructive, action: reset)
    } message: {
      Text("Lentera activates a new anonymous device on the next conversion. Some ACSM files that were opened with this activation can then fail.")
    }
    .alert(message?.title ?? "", isPresented: messageBinding) {
      Button("OK") {}
    } message: {
      Text(message?.body ?? "")
    }
  }

  private var statusText: String {
    switch account {
    case nil: "Not activated. Lentera activates on the first conversion."
    case .anonymous?: "Anonymous device" + since
    case .adobeID(let name)?: name + since
    }
  }

  private var since: String {
    activatedOn.map { " · since \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""
  }

  private var importBinding: Binding<Bool> {
    Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } })
  }

  private var messageBinding: Binding<Bool> {
    Binding(get: { message != nil }, set: { if !$0 { message = nil } })
  }

  private func refresh() {
    account = AdobeActivation.isActivated() ? AdobeActivation.account() ?? .anonymous : nil
    activatedOn = account == nil ? nil : AdobeActivation.activationDate()
  }

  private func export() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.zip]
    panel.nameFieldStringValue = "Lentera Activation.zip"
    panel.prompt = "Export"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    perform("Could not export the activation") {
      try await AdobeActivation.export(to: url)
      NSWorkspace.shared.activateFileViewerSelecting([url])
    }
  }

  private func chooseImport() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.zip, .folder]
    panel.canChooseDirectories = true
    panel.message = "Choose a Lentera activation backup, or a folder with activation.xml."
    panel.prompt = "Import"
    if panel.runModal() == .OK, let url = panel.url { pendingImport = url }
  }

  private func runImport(_ url: URL) {
    perform("Could not import the activation") {
      try await AdobeActivation.importBackup(from: url)
      message = ("Activation imported", "Lentera uses this activation for new conversions.")
    }
  }

  private func reset() {
    perform("Could not reset the activation") { try AdobeActivation.reset() }
  }

  private func perform(_ failureTitle: String, _ work: @escaping () async throws -> Void) {
    isWorking = true
    Task {
      do {
        try await work()
      } catch {
        message = (failureTitle, error.localizedDescription)
      }
      isWorking = false
      refresh()
    }
  }
}
