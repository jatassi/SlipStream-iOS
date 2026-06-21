import Foundation
import Observation

public enum AuthError: Error, Equatable, Sendable {
  case invalidPIN
  case badCredentials
  case server(status: Int)
  case network(String)
}

@MainActor
@Observable
public final class AuthStore {
  public enum State: Equatable {
    case signedOut
    case signedIn(PortalUser)
  }

  public private(set) var state: State = .signedOut
  public private(set) var lastError: AuthError?
  public private(set) var hasAttemptedRestore = false

  private let makeAuthAPI: @Sendable (URL) -> AuthAPI
  private let tokenStore: TokenStore
  private let serverConfig: ServerConfigStore
  private let lastUsernameStore: LastUsernameStore
  private var token: String?

  public init(
    makeAuthAPI: @escaping @Sendable (URL) -> AuthAPI,
    tokenStore: TokenStore,
    serverConfig: ServerConfigStore,
    lastUsernameStore: LastUsernameStore
  ) {
    self.makeAuthAPI = makeAuthAPI
    self.tokenStore = tokenStore
    self.serverConfig = serverConfig
    self.lastUsernameStore = lastUsernameStore
  }

  public var currentToken: String? { token }
  public var serverBaseURLString: String? { serverConfig.baseURL?.absoluteString }

  /// The last successfully signed-in username, for pre-filling the sign-in form.
  public var lastUsername: String? { lastUsernameStore.lastUsername }

  /// Try to resume a session: load the JWT (Face ID), validate it by fetching the profile.
  public func restore() async {
    defer { hasAttemptedRestore = true }
    guard let url = serverConfig.baseURL else {
      state = .signedOut
      return
    }
    do {
      guard let stored = try await tokenStore.load() else {
        state = .signedOut
        return
      }
      let user = try await makeAuthAPI(url).profile(token: stored)
      token = stored
      state = .signedIn(user)
    } catch let APIClientError.http(status, _, _) where status == 401 {
      // 30-day JWT expired: clear it so the next sign-in is clean.
      try? tokenStore.delete()
      token = nil
      state = .signedOut
    } catch {
      // Network failure or biometric cancel: stay signed out, keep the token for a later retry.
      state = .signedOut
    }
  }

  /// Authenticate username + 4-digit PIN, persist the JWT and server URL on success.
  public func signIn(serverURL: URL, username: String, pin: String) async {
    lastError = nil
    guard isValidPIN(pin) else {
      lastError = .invalidPIN
      return
    }
    do {
      let resp = try await makeAuthAPI(serverURL)
        .login(LoginRequest(username: username, password: pin))
      try tokenStore.save(resp.token)
      serverConfig.setBaseURL(serverURL)
      lastUsernameStore.setLastUsername(username)
      token = resp.token
      state = .signedIn(resp.user)
    } catch let APIClientError.http(status, _, _) where status == 401 {
      lastError = .badCredentials
    } catch let APIClientError.http(status, _, _) {
      lastError = .server(status: status)
    } catch let APIClientError.transport(message) {
      lastError = .network(message)
    } catch let APIClientError.decoding(message) {
      lastError = .network(message)
    } catch {
      lastError = .network(String(describing: error))
    }
  }

  public func signOut() {
    try? tokenStore.delete()
    token = nil
    state = .signedOut
  }

  /// Dismiss the current sign-in error (e.g. when the user starts over via
  /// "Switch User") so a stale failure message doesn't linger over a fresh form.
  public func clearError() {
    lastError = nil
  }

  private func isValidPIN(_ pin: String) -> Bool {
    pin.count == 4 && pin.allSatisfy(\.isNumber)
  }
}
