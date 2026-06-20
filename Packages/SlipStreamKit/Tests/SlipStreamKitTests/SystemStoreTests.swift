import Testing
import Foundation
@testable import SlipStreamKit

@MainActor
@Suite struct SystemStoreTests {
    let serverURL = URL(string: "https://slipstream.example.com")!

    private func makeStore(
        api: FakeSystemAPI,
        config: FakeServerConfigStore
    ) -> SystemStore {
        SystemStore(makeSystemAPI: { _ in api }, serverConfig: config)
    }

    @Test func refreshSuccessStoresStatusAndModules() async {
        let api = FakeSystemAPI(onStatus: { sampleStatus(enabledModules: ["movie": true, "tv": false]) })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: serverURL))

        await store.refresh()

        #expect(store.status != nil)
        #expect(store.portalEnabled == true)
        #expect(store.enabledModuleTypes == [.movie])
        #expect(store.lastError == nil)
    }

    @Test func refreshWithNoServerURLKeepsOptimisticDefaults() async {
        let api = FakeSystemAPI(onStatus: {
            Issue.record("should not call /status without a configured server")
            return sampleStatus()
        })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: nil))

        await store.refresh()

        #expect(store.status == nil)
        #expect(store.portalEnabled == true)
        #expect(store.enabledModuleTypes == ModuleType.allCases)
        #expect(store.lastError == nil)
    }

    @Test func refreshFailureSetsErrorAndKeepsOptimisticDefaults() async {
        let api = FakeSystemAPI(onStatus: { throw APIClientError.http(status: 503, message: nil, error: nil) })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: serverURL))

        await store.refresh()

        #expect(store.lastError == .http(status: 503, message: nil, error: nil))
        #expect(store.status == nil)
        #expect(store.portalEnabled == true)              // optimistic default retained
        #expect(store.enabledModuleTypes == ModuleType.allCases)
    }

    @Test func portalDisabledPropagates() async {
        let api = FakeSystemAPI(onStatus: { sampleStatus(portalEnabled: false) })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: serverURL))

        await store.refresh()

        #expect(store.portalEnabled == false)
    }

    @Test func requestableModulesIntersectsUserWithServer() async {
        let api = FakeSystemAPI(onStatus: { sampleStatus(enabledModules: ["movie": true, "tv": false]) })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: serverURL))
        await store.refresh()

        let user = sampleUser(moduleTypes: ["movie", "tv"])
        #expect(store.requestableModules(for: user) == [.movie])   // tv disabled server-side
    }

    @Test func requestableModulesUsesOptimisticDefaultBeforeLoad() {
        let api = FakeSystemAPI(onStatus: { sampleStatus() })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: serverURL))
        // No refresh() → status is nil → optimistic default (all modules enabled).

        let user = sampleUser(moduleTypes: ["tv"])
        #expect(store.requestableModules(for: user) == [.tv])
    }
}
