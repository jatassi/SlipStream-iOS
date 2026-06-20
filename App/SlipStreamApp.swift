import SwiftUI
import SlipStreamKit

@main
struct SlipStreamApp: App {
    @State private var auth = AuthStore(
        makeAuthAPI: { url in PortalAPIClient(baseURL: url) },
        tokenStore: KeychainTokenStore(),
        serverConfig: UserDefaultsServerConfigStore()
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
    }
}
