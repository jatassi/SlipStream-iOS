import Foundation
import Testing

@testable import SlipStreamKit

@MainActor
@Suite struct AuthStoreTests {
  let serverURL = URL(string: "https://slipstream.example.com")!

  private func makeStore(
    api: FakeAuthAPI,
    tokenStore: FakeTokenStore = FakeTokenStore(),
    config: FakeServerConfigStore = FakeServerConfigStore(),
    lastUsername: FakeLastUsernameStore = FakeLastUsernameStore()
  ) -> AuthStore {
    AuthStore(
      makeAuthAPI: { _ in api },
      tokenStore: tokenStore,
      serverConfig: config,
      lastUsernameStore: lastUsername
    )
  }

  @Test func signInRejectsNonFourDigitPIN() async {
    let api = FakeAuthAPI(
      onLogin: { _ in
        Issue.record("should not call login")
        throw APIClientError.transport("x")
      },
      onProfile: { _ in sampleUser() }
    )
    let tokens = FakeTokenStore()
    let store = makeStore(api: api, tokenStore: tokens)

    await store.signIn(serverURL: serverURL, username: "jack", pin: "12")

    #expect(store.lastError == .invalidPIN)
    #expect(store.state == .signedOut)
    #expect(tokens.saveCount == 0)
  }

  @Test func signInSuccessStoresTokenAndConfig() async {
    let api = FakeAuthAPI(
      onLogin: { _ in LoginResponse(token: "tok", user: sampleUser(), isAdmin: false) },
      onProfile: { _ in sampleUser() }
    )
    let tokens = FakeTokenStore()
    let config = FakeServerConfigStore()
    let store = makeStore(api: api, tokenStore: tokens, config: config)

    await store.signIn(serverURL: serverURL, username: "jack", pin: "1234")

    #expect(store.state == .signedIn(sampleUser()))
    #expect(store.currentToken == "tok")
    #expect(tokens.stored == "tok")
    #expect(config.baseURL == serverURL)
    #expect(store.lastError == nil)
  }

  @Test func signInBadCredentialsSetsError() async {
    let api = FakeAuthAPI(
      onLogin: { _ in throw APIClientError.http(status: 401, message: "bad", error: nil) },
      onProfile: { _ in sampleUser() }
    )
    let store = makeStore(api: api)

    await store.signIn(serverURL: serverURL, username: "jack", pin: "0000")

    #expect(store.lastError == .badCredentials)
    #expect(store.state == .signedOut)
  }

  @Test func restoreWithValidTokenSignsIn() async {
    let api = FakeAuthAPI(
      onLogin: { _ in throw APIClientError.transport("x") },
      onProfile: { token in
        #expect(token == "saved")
        return sampleUser(username: "restored")
      }
    )
    let tokens = FakeTokenStore(stored: "saved")
    let config = FakeServerConfigStore(url: serverURL)
    let store = makeStore(api: api, tokenStore: tokens, config: config)

    await store.restore()

    #expect(store.state == .signedIn(sampleUser(username: "restored")))
    #expect(store.hasAttemptedRestore == true)
  }

  @Test func restoreWithExpiredTokenDeletesAndSignsOut() async {
    let api = FakeAuthAPI(
      onLogin: { _ in throw APIClientError.transport("x") },
      onProfile: { _ in throw APIClientError.http(status: 401, message: nil, error: nil) }
    )
    let tokens = FakeTokenStore(stored: "expired")
    let config = FakeServerConfigStore(url: serverURL)
    let store = makeStore(api: api, tokenStore: tokens, config: config)

    await store.restore()

    #expect(store.state == .signedOut)
    #expect(tokens.stored == nil)
    #expect(tokens.deleteCount == 1)
    #expect(store.hasAttemptedRestore == true)
  }

  @Test func restoreWithNoConfigSignsOut() async {
    let api = FakeAuthAPI(
      onLogin: { _ in throw APIClientError.transport("x") },
      onProfile: { _ in sampleUser() }
    )
    let store = makeStore(api: api, config: FakeServerConfigStore(url: nil))

    await store.restore()

    #expect(store.state == .signedOut)
    #expect(store.hasAttemptedRestore == true)
  }

  @Test func signInSuccessRemembersUsername() async {
    let api = FakeAuthAPI(
      onLogin: { _ in LoginResponse(token: "tok", user: sampleUser(), isAdmin: false) },
      onProfile: { _ in sampleUser() }
    )
    let remembered = FakeLastUsernameStore()
    let store = makeStore(api: api, lastUsername: remembered)

    await store.signIn(serverURL: serverURL, username: "jack", pin: "1234")

    #expect(remembered.lastUsername == "jack")
    #expect(remembered.setCount == 1)
    #expect(store.lastUsername == "jack")
  }

  @Test func signInBadCredentialsDoesNotRememberUsername() async {
    let api = FakeAuthAPI(
      onLogin: { _ in throw APIClientError.http(status: 401, message: "bad", error: nil) },
      onProfile: { _ in sampleUser() }
    )
    let remembered = FakeLastUsernameStore()
    let store = makeStore(api: api, lastUsername: remembered)

    await store.signIn(serverURL: serverURL, username: "jack", pin: "0000")

    #expect(remembered.lastUsername == nil)
    #expect(remembered.setCount == 0)
    #expect(store.lastUsername == nil)
  }

  @Test func invalidPINDoesNotRememberUsername() async {
    let api = FakeAuthAPI(
      onLogin: { _ in
        Issue.record("should not call login")
        throw APIClientError.transport("x")
      },
      onProfile: { _ in sampleUser() }
    )
    let remembered = FakeLastUsernameStore()
    let store = makeStore(api: api, lastUsername: remembered)

    await store.signIn(serverURL: serverURL, username: "jack", pin: "12")

    #expect(remembered.setCount == 0)
    #expect(store.lastUsername == nil)
  }

  @Test func exposesRememberedUsernameFromStore() {
    let api = FakeAuthAPI(
      onLogin: { _ in throw APIClientError.transport("x") },
      onProfile: { _ in sampleUser() }
    )
    let store = makeStore(api: api, lastUsername: FakeLastUsernameStore(lastUsername: "remembered"))

    #expect(store.lastUsername == "remembered")
  }

  @Test func clearErrorResetsLastError() async {
    let api = FakeAuthAPI(
      onLogin: { _ in throw APIClientError.http(status: 401, message: "bad", error: nil) },
      onProfile: { _ in sampleUser() }
    )
    let store = makeStore(api: api)

    await store.signIn(serverURL: serverURL, username: "jack", pin: "0000")
    #expect(store.lastError == .badCredentials)

    store.clearError()
    #expect(store.lastError == nil)
  }
}
