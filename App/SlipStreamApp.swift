import SlipStreamKit
import SwiftUI

@main
struct SlipStreamApp: App {
  @State private var auth: AuthStore
  @State private var system = SystemStore(
    makeSystemAPI: { url in PortalAPIClient(baseURL: url) },
    serverConfig: UserDefaultsServerConfigStore()
  )
  @State private var poller: PollingEngine

  init() {
    let initialAuth = AuthStore(
      makeAuthAPI: { url in PortalAPIClient(baseURL: url) },
      tokenStore: KeychainTokenStore(),
      serverConfig: UserDefaultsServerConfigStore()
    )
    // A 401 from any poll means the JWT expired: sign out. (F2.4 expands the recovery UX.)
    let initialPoller = PollingEngine(onUnauthorized: { [weak initialAuth] in
      Task { initialAuth?.signOut() }
    })
    _auth = State(initialValue: initialAuth)
    _poller = State(initialValue: initialPoller)
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(system)
        .environment(poller)
    }
  }
}
