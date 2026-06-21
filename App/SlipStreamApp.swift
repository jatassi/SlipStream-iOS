import DesignSystem
import SlipStreamKit
import SwiftUI

@main
struct SlipStreamApp: App {
  @State private var auth: AuthStore
  @State private var system: SystemStore
  @State private var poller: PollingEngine
  @State private var navigation = NavigationModel()
  @State private var posterSize = PosterSizePreference(store: UserDefaultsPosterSizeStore())

  init() {
    // Install the Nuke poster pipeline (and the Inter typeface) before any view renders.
    DesignTheme.bootstrap()

    // Central session-expiry handler. A token-bearing 401 from any portal call routes here to
    // pause the poller and sign out (F2.4). `auth`/`poller` are assigned after the stores exist
    // — they reference each other, so the wiring is two-phase. (`PortalAPIClient.onUnauthorized`
    // already fires only for token-bearing 401s, so a bad-PIN login never triggers it.)
    let expiry = SessionExpiry()
    // The client hook is `@Sendable` and fires off the main actor, so it must hop via `Task`;
    // the `PollingEngine` hook below is already `@MainActor` and calls through directly. Keep both
    // — dropping the hop on the client path would be a main-actor violation; adding one to the
    // poll path would needlessly defer sign-out a runloop turn.
    let onUnauthorized: @Sendable () -> Void = {
      Task { @MainActor in expiry.handleUnauthorized() }
    }

    let initialAuth = AuthStore(
      makeAuthAPI: { url in PortalAPIClient(baseURL: url, onUnauthorized: onUnauthorized) },
      tokenStore: KeychainTokenStore(),
      serverConfig: UserDefaultsServerConfigStore(),
      lastUsernameStore: UserDefaultsLastUsernameStore()
    )
    // System discovery only calls public `/status` (tokenless), so this hook is dormant today; it
    // keeps the "every factory wires the hook" convention so a future token-bearing call here
    // (e.g. `/metadata`) is covered by construction rather than by remembering to add it.
    let initialSystem = SystemStore(
      makeSystemAPI: { url in PortalAPIClient(baseURL: url, onUnauthorized: onUnauthorized) },
      serverConfig: UserDefaultsServerConfigStore()
    )
    // A 401 from a poll also routes through the same handler (the engine additionally self-suspends
    // and stops its drivers; suspend() is then a guarded no-op here).
    let initialPoller = PollingEngine(onUnauthorized: { expiry.handleUnauthorized() })

    expiry.auth = initialAuth
    expiry.poller = initialPoller

    _auth = State(initialValue: initialAuth)
    _system = State(initialValue: initialSystem)
    _poller = State(initialValue: initialPoller)
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(system)
        .environment(poller)
        .environment(navigation)
        .environment(posterSize)
        .preferredColorScheme(.dark)
    }
  }
}
