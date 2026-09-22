import Observation
import Sparkle
import SwiftUI

@MainActor
@Observable
final class CheckForUpdatesModel {
  private(set) var canCheckForUpdates = false
  @ObservationIgnored private var observation: NSKeyValueObservation?

  init(updater: SPUUpdater) {
    canCheckForUpdates = updater.canCheckForUpdates
    observation = updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, change in
      guard let value = change.newValue else { return }
      Task { @MainActor in self?.canCheckForUpdates = value }
    }
  }
}

struct CheckForUpdatesView: View {
  private let updater: SPUUpdater
  @State private var model: CheckForUpdatesModel

  init(updater: SPUUpdater) {
    self.updater = updater
    _model = State(initialValue: CheckForUpdatesModel(updater: updater))
  }

  var body: some View {
    Button("Check for Updates…", action: updater.checkForUpdates)
      .disabled(!model.canCheckForUpdates)
  }
}
