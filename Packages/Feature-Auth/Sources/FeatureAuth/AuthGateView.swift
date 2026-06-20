import SlipStreamKit
import SwiftUI

/// Drives the top-level auth flow: a spinner until restore finishes, then either
/// the sign-in form (signed out) or the caller's signed-in content.
public struct AuthGateView<SignedIn: View>: View {
  @Environment(AuthStore.self) private var auth
  private let signedIn: () -> SignedIn

  public init(@ViewBuilder signedIn: @escaping () -> SignedIn) {
    self.signedIn = signedIn
  }

  public var body: some View {
    Group {
      if !auth.hasAttemptedRestore {
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
    .task { await auth.restore() }
  }
}
