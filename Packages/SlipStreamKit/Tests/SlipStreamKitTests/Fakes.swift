import Foundation
@testable import SlipStreamKit

final class FakeTokenStore: TokenStore, @unchecked Sendable {
    var stored: String?
    private(set) var saveCount = 0
    private(set) var deleteCount = 0
    init(stored: String? = nil) { self.stored = stored }
    func save(_ token: String) throws { stored = token; saveCount += 1 }
    func load() async throws -> String? { stored }
    func delete() throws { stored = nil; deleteCount += 1 }
}

final class FakeServerConfigStore: ServerConfigStore, @unchecked Sendable {
    var url: URL?
    init(url: URL? = nil) { self.url = url }
    var baseURL: URL? { url }
    func setBaseURL(_ url: URL) { self.url = url }
}

struct FakeAuthAPI: AuthAPI {
    var onLogin: @Sendable (LoginRequest) async throws -> LoginResponse
    var onProfile: @Sendable (String) async throws -> PortalUser
    func login(_ body: LoginRequest) async throws -> LoginResponse { try await onLogin(body) }
    func profile(token: String) async throws -> PortalUser { try await onProfile(token) }
}

func sampleUser(username: String = "jack") -> PortalUser {
    PortalUser(
        id: 1, username: username, moduleSettings: [],
        autoApprove: true, enabled: true, isAdmin: false,
        createdAt: "t", updatedAt: "t"
    )
}
