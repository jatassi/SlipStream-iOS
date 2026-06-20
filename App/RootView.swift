import FeatureAuth
import FeatureShell
import SlipStreamKit
import SwiftUI

struct RootView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(PollingEngine.self) private var poller
  @Environment(SystemStore.self) private var system

  var body: some View {
    AuthGateView {
      AppShellView()
        // Re-enable polling on a fresh sign-in: a prior 401 suspends the engine
        // (PollingEngine.handleUnauthorized) and only resume() clears it. (F2.4
        // expands the recovery UX.)
        .onAppear { poller.resume() }
        // Refresh system discovery (enabled modules + portalEnabled) on the
        // signed-in path. F1.4 wiring; previously triggered by the removed
        // SignedInPlaceholderView. Downstream features (F2.6, F3.x) read this.
        .task { await system.refresh() }
    }
    .onChange(of: scenePhase, initial: true) { _, phase in
      poller.setActivity(activity(for: phase))
    }
  }

  private func activity(for phase: ScenePhase) -> PollingActivity {
    switch phase {
    case .active: .active
    case .inactive: .inactive
    case .background: .background
    @unknown default: .inactive
    }
  }
}
