import Combine
import Observation
import Sparkle
import SwiftUI

@MainActor
@Observable
final class CheckForUpdatesModel {
  private(set) var canCheckForUpdates = false
  @ObservationIgnored private var cancellable: AnyCancellable?

  init(updater: SPUUpdater) {
    canCheckForUpdates = updater.canCheckForUpdates
    cancellable = updater.publisher(for: \.canCheckForUpdates)
      .receive(on: RunLoop.main)
      .sink { [weak self] in self?.canCheckForUpdates = $0 }
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
