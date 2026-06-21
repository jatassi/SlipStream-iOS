import Foundation

@testable import SlipStreamKit

final class FakeTokenStore: TokenStore, @unchecked Sendable {
  var stored: String?
  private(set) var saveCount = 0
  private(set) var deleteCount = 0
  init(stored: String? = nil) { self.stored = stored }
  func save(_ token: String) throws {
    stored = token
    saveCount += 1
  }
  func load() async throws -> String? { stored }
  func delete() throws {
    stored = nil
    deleteCount += 1
  }
}

final class FakeServerConfigStore: ServerConfigStore, @unchecked Sendable {
  var url: URL?
  init(url: URL? = nil) { self.url = url }
  var baseURL: URL? { url }
  func setBaseURL(_ url: URL) { self.url = url }
}

final class FakeLastUsernameStore: LastUsernameStore, @unchecked Sendable {
  var lastUsername: String?
  private(set) var setCount = 0
  init(lastUsername: String? = nil) { self.lastUsername = lastUsername }
  func setLastUsername(_ username: String) {
    lastUsername = username
    setCount += 1
  }
}

struct FakeAuthAPI: AuthAPI {
  var onLogin: @Sendable (LoginRequest) async throws -> LoginResponse
  var onProfile: @Sendable (String) async throws -> PortalUser
  func login(_ body: LoginRequest) async throws -> LoginResponse { try await onLogin(body) }
  func profile(token: String) async throws -> PortalUser { try await onProfile(token) }
}

func sampleUser(username: String = "jack", moduleTypes: [String] = []) -> PortalUser {
  PortalUser(
    id: 1, username: username,
    moduleSettings: moduleTypes.map { UserModuleSetting(moduleType: $0, qualityProfileId: nil) },
    autoApprove: true, enabled: true, isAdmin: false,
    createdAt: "t", updatedAt: "t"
  )
}

struct FakeSystemAPI: SystemAPI {
  var onStatus: @Sendable () async throws -> SystemStatus
  func status() async throws -> SystemStatus { try await onStatus() }
}

func sampleStatus(
  portalEnabled: Bool = true,
  enabledModules: [String: Bool]? = ["movie": true, "tv": true]
) -> SystemStatus {
  SystemStatus(portalEnabled: portalEnabled, enabledModules: enabledModules)
}
