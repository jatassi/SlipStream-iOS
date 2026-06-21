/// Central reaction to an expired or rejected session: a token-bearing `401` from **any**
/// portal call — a background poll or a user-initiated request — pauses polling and signs the
/// user out, returning them to PIN entry. There is no refresh token, so recovery *is* re-entering
/// the PIN; the return to login is silent (no extra messaging), mirroring the web portal.
///
/// It mediates between `AuthStore` and `PollingEngine` without belonging to either. The app wires
/// the same `handleUnauthorized` into every `PortalAPIClient.onUnauthorized` hook and into
/// `PollingEngine.onUnauthorized`, so both the non-poll and poll paths funnel through one place.
///
/// The references are `weak` and settable so the app can assign them **after** building the stores
/// — resolving the construction cycle (the clients need the poller, but the poller is built after
/// the auth store) and avoiding a retain cycle (the client factories capture `self` strongly and
/// are owned by the stores).
@MainActor
public final class SessionExpiry {
  public weak var auth: AuthStore?
  public weak var poller: PollingEngine?

  public init() {}

  /// Pause polling immediately, then sign out. Suspending *before* signing out stops a burst of
  /// in-flight polls from piling up during the transition.
  ///
  /// No-op unless we currently believe we're signed in. A 401 that arrives after we've already
  /// returned to PIN entry — a late/duplicate hook, or the client hook firing during `restore()`'s
  /// own startup-401 handling — is ignored, so the poller isn't stranded `isSuspended` on the
  /// sign-in screen (where only `AppShellView.onAppear` would `resume()` it). The guard also makes
  /// a single expired token reaching both the poll path and the client hook react exactly once.
  /// (It does not distinguish *which* session a stale 401 belonged to; a same-session wrong-logout
  /// would require a full re-auth to land between this deferred call's enqueue and its execution,
  /// which main-actor serialization plus human latency make unreachable.)
  public func handleUnauthorized() {
    guard let auth, case .signedIn = auth.state else { return }
    poller?.suspend()
    auth.signOut()
  }
}
