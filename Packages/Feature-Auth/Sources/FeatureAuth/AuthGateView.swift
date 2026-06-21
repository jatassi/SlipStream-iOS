import SlipStreamKit
import SwiftUI

/// Drives the top-level auth flow. The portal-disabled gate (F2.6) is the first
/// branch: a server `portalEnabled == false` replaces *everything* — the spinner,
/// the sign-in form, and the signed-in content. Otherwise: a spinner until restore
/// finishes, then either the sign-in form (signed out) or the caller's signed-in content.
public struct AuthGateView<SignedIn: View>: View {
  @Environment(AuthStore.self) private var auth
  @Environment(SystemStore.self) private var system
  private let signedIn: () -> SignedIn

  public init(@ViewBuilder signedIn: @escaping () -> SignedIn) {
    self.signedIn = signedIn
  }

  public var body: some View {
    Group {
      if !system.portalEnabled {
        PortalDisabledView()
      } else if !auth.hasAttemptedRestore {
        ProgressView("Unlocking…")
      } else {
        switch auth.state {
        case .signedIn:
          signedIn()
        case .signedOut:
          SignInView()
        }
      }
    }
    // Keep restoring underneath the gate: if the portal flips back on (foreground
    // refresh), an already-restored session shows the shell immediately.
    .task { await auth.restore() }
  }
}
