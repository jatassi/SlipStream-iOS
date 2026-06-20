import SlipStreamKit
import SwiftUI

@main
struct SlipStreamApp: App {
  @State private var auth = AuthStore(
    makeAuthAPI: { url in PortalAPIClient(baseURL: url) },
    tokenStore: KeychainTokenStore(),
    serverConfig: UserDefaultsServerConfigStore()
  )
  @State private var system = SystemStore(
    makeSystemAPI: { url in PortalAPIClient(baseURL: url) },
    serverConfig: UserDefaultsServerConfigStore()
  )

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(system)
    }
  }
}
