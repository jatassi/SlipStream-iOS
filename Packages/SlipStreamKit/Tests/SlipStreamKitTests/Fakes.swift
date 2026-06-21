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
  var onValidateInvitation: @Sendable (String) async throws -> ValidateInvitationResponse = { _ in
    throw APIClientError.transport("validateInvitation not stubbed")
  }
  var onSignup: @Sendable (SignupRequest) async throws -> SignupResponse = { _ in
    throw APIClientError.transport("signup not stubbed")
  }
  func login(_ body: LoginRequest) async throws -> LoginResponse { try await onLogin(body) }
  func profile(token: String) async throws -> PortalUser { try await onProfile(token) }
  func validateInvitation(token: String) async throws -> ValidateInvitationResponse {
    try await onValidateInvitation(token)
  }
  func signup(_ body: SignupRequest) async throws -> SignupResponse { try await onSignup(body) }
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

struct FakeMediaAPI: MediaAPI {
  var onMovies: @Sendable (String) async throws -> [PortalMovieSearchResult] = { _ in [] }
  var onSeries: @Sendable (String) async throws -> [PortalSeriesSearchResult] = { _ in [] }
  func libraryMovies(token: String) async throws -> [PortalMovieSearchResult] {
    try await onMovies(token)
  }
  func librarySeries(token: String) async throws -> [PortalSeriesSearchResult] {
    try await onSeries(token)
  }
}

final class FakeLibraryTabStore: LibraryTabStore, @unchecked Sendable {
  private var tab: LibraryTab
  private(set) var setCount = 0
  init(tab: LibraryTab = .movies) { self.tab = tab }
  var selectedTab: LibraryTab { tab }
  func setSelectedTab(_ tab: LibraryTab) {
    self.tab = tab
    setCount += 1
  }
}

/// Thread-safe call counter for asserting fetch counts from `@Sendable` fake closures.
final class CallCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0
  var count: Int { lock.withLock { value } }
  func increment() { lock.withLock { value += 1 } }
}

func sampleMovie(id: Int = 1, title: String = "The Matrix") -> PortalMovieSearchResult {
  PortalMovieSearchResult(id: id, tmdbId: 603, title: title, year: 1999)
}

func sampleSeries(id: Int = 2, title: String = "Game of Thrones") -> PortalSeriesSearchResult {
  PortalSeriesSearchResult(id: id, tmdbId: 1399, title: title, tvdbId: 121_361, year: 2011)
}
