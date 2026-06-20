import FeatureAuth
import SlipStreamKit
import SwiftUI

struct RootView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(PollingEngine.self) private var poller

  var body: some View {
    AuthGateView {
      SignedInPlaceholderView()
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
