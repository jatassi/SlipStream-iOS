import DesignSystem
import FeatureAuth
import FeatureShell
import SlipStreamKit
import SwiftUI

struct RootView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(AuthStore.self) private var auth
  @Environment(PollingEngine.self) private var poller
  @Environment(SystemStore.self) private var system

  #if DEBUG
    @State private var showingGallery = false
  #endif

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
    // Drop cached poster artwork whenever the session ends — manual sign-out or
    // F2.4's future 401 auto-logout. Shared family device. (F1.7)
    .onChange(of: auth.state) { _, state in
      if state == .signedOut { PosterImagePipeline.clearImageCache() }
    }
    #if DEBUG
      .overlay(alignment: .bottomTrailing) { galleryButton }
      .sheet(isPresented: $showingGallery) {
        NavigationStack { DesignSystemGalleryView() }
      }
    #endif
  }

  #if DEBUG
    /// A floating DEBUG-only affordance that opens the DesignSystem gallery from
    /// anywhere (including signed-out), without nesting a `TabView` in the shell.
    private var galleryButton: some View {
      Button {
        showingGallery = true
      } label: {
        Image(systemName: "swatchpalette.fill")
          .padding(12)
          .background(.ultraThinMaterial, in: Circle())
      }
      .padding()
      .accessibilityLabel("Design System Gallery")
    }
  #endif

  private func activity(for phase: ScenePhase) -> PollingActivity {
    switch phase {
    case .active: .active
    case .inactive: .inactive
    case .background: .background
    @unknown default: .inactive
    }
  }
}
