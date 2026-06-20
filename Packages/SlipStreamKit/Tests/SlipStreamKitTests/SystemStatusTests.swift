import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct SystemStatusTests {
    /// A realistic (trimmed) `/api/v1/status` payload — extra fields must be ignored on decode.
    private let statusJSON = """
    {
      "version": "1.2.3",
      "startTime": "2026-06-20T00:00:00Z",
      "movieCount": 42,
      "seriesCount": 7,
      "developerMode": false,
      "isDevBuild": false,
      "portalEnabled": true,
      "requiresSetup": false,
      "requiresAuth": true,
      "mediainfoAvailable": true,
      "enabledModules": { "movie": true, "tv": false },
      "tmdb": { "disableSearchOrdering": false }
    }
    """

    private func user(modules: [String]) -> PortalUser {
        PortalUser(
            id: 1, username: "jack",
            moduleSettings: modules.map { UserModuleSetting(moduleType: $0, qualityProfileId: nil) },
            autoApprove: true, enabled: true, isAdmin: false,
            createdAt: "t", updatedAt: "t"
        )
    }

    @Test func moduleTypeRawValuesAndOrder() {
        #expect(ModuleType.movie.rawValue == "movie")
        #expect(ModuleType.tv.rawValue == "tv")
        #expect(ModuleType.allCases == [.movie, .tv])
    }

    @Test func decodesStatusIgnoringExtraFields() throws {
        let status = try JSONDecoder().decode(SystemStatus.self, from: Data(statusJSON.utf8))
        #expect(status.portalEnabled == true)
        #expect(status.enabledModules == ["movie": true, "tv": false])
        // tv is present-but-false → excluded.
        #expect(status.enabledModuleTypes == [.movie])
    }

    @Test func bothModulesEnabledKeepsCanonicalOrder() {
        let status = SystemStatus(portalEnabled: true, enabledModules: ["tv": true, "movie": true])
        #expect(status.enabledModuleTypes == [.movie, .tv])
    }

    @Test func unknownModuleStringIsIgnored() {
        let status = SystemStatus(portalEnabled: true, enabledModules: ["movie": true, "music": true])
        #expect(status.enabledModuleTypes == [.movie])
    }

    @Test func nilModulesMapFallsBackToAllKnownModules() {
        let status = SystemStatus(portalEnabled: true, enabledModules: nil)
        #expect(status.enabledModuleTypes == ModuleType.allCases)
    }

    @Test func requestableModulesIntersectsUserWithServer() {
        let status = SystemStatus(portalEnabled: true, enabledModules: ["movie": true, "tv": true])
        #expect(status.requestableModules(for: user(modules: ["movie"])) == [.movie])
    }

    @Test func requestableModulesExcludesServerDisabledModule() {
        let status = SystemStatus(portalEnabled: true, enabledModules: ["movie": true, "tv": false])
        #expect(status.requestableModules(for: user(modules: ["movie", "tv"])) == [.movie])
    }

    @Test func requestableModulesEmptyWhenUserAllowsNone() {
        let status = SystemStatus(portalEnabled: true, enabledModules: ["movie": true, "tv": true])
        #expect(status.requestableModules(for: user(modules: [])) == [])
    }

    @Test func optimisticDefaultIsPermissive() {
        #expect(SystemStatus.optimisticDefault.portalEnabled == true)
        #expect(SystemStatus.optimisticDefault.enabledModuleTypes == ModuleType.allCases)
    }
}
