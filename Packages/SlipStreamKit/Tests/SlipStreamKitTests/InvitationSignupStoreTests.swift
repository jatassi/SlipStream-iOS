import Foundation
import Testing

@testable import SlipStreamKit

/// Holds a deferred reference to the store so a `FakeAuthAPI` closure can call back into it
/// (e.g. simulate `reset()` racing an in-flight validation). `@MainActor` types are `Sendable`,
/// so the reference crosses into the `@Sendable` closure safely; it's written once before the
/// async work and read once during it, so the unchecked conformance is sound.
private final class StoreBox: @unchecked Sendable {
  var store: InvitationSignupStore?
}

@MainActor
@Suite struct InvitationSignupStoreTests {
  let link = "https://invite.example.com/signup?token=INVITE-TOK"

  /// Builds a store backed by `api`, with a real `AuthStore` (wired to `tokens`) so the
  /// success path actually commits a session. Returns all three for assertions.
  private func makeStore(
    _ api: FakeAuthAPI,
    config: FakeServerConfigStore = FakeServerConfigStore()
  ) -> (InvitationSignupStore, AuthStore, FakeTokenStore) {
    let tokens = FakeTokenStore()
    let auth = AuthStore(
      makeAuthAPI: { _ in api },
      tokenStore: tokens,
      serverConfig: FakeServerConfigStore(),
      lastUsernameStore: FakeLastUsernameStore()
    )
    let store = InvitationSignupStore(
      makeAuthAPI: { _ in api }, serverConfig: config, auth: auth)
    return (store, auth, tokens)
  }

  private func baseAPI(
    onValidateInvitation: @escaping @Sendable (String) async throws -> ValidateInvitationResponse =
      { _ in ValidateInvitationResponse(valid: true, username: "newbie", expiresAt: "t") },
    onSignup: @escaping @Sendable (SignupRequest) async throws -> SignupResponse = { _ in
      SignupResponse(token: "session-jwt", user: sampleUser(username: "newbie"))
    }
  ) -> FakeAuthAPI {
    FakeAuthAPI(
      onLogin: { _ in throw APIClientError.transport("x") },
      onProfile: { _ in sampleUser() },
      onValidateInvitation: onValidateInvitation,
      onSignup: onSignup
    )
  }

  @Test func submitValidLinkBecomesReady() async {
    let api = baseAPI(onValidateInvitation: { token in
      #expect(token == "INVITE-TOK")
      return ValidateInvitationResponse(valid: true, username: "newbie", expiresAt: "t")
    })
    let (store, _, _) = makeStore(api)
    await store.submitInviteLink(link)
    #expect(store.phase == .ready(username: "newbie"))
    #expect(store.pasteError == nil)
  }

  @Test func unparseablePasteStaysAwaitingTokenWithError() async {
    let (store, _, _) = makeStore(baseAPI(), config: FakeServerConfigStore(url: nil))
    await store.submitInviteLink("not a link")
    #expect(store.phase == .awaitingToken)
    #expect(store.pasteError != nil)
  }

  @Test func validateNotFoundBecomesInvalid() async {
    let api = baseAPI(onValidateInvitation: { _ in
      throw APIClientError.http(status: 404, message: nil, error: "invitation not found")
    })
    let (store, _, _) = makeStore(api)
    await store.submitInviteLink(link)
    #expect(store.phase == .invalid(.notFound))
  }

  @Test func validateExpiredBecomesInvalid() async {
    let api = baseAPI(onValidateInvitation: { _ in
      throw APIClientError.http(status: 410, message: nil, error: "expired")
    })
    let (store, _, _) = makeStore(api)
    await store.submitInviteLink(link)
    #expect(store.phase == .invalid(.expired))
  }

  @Test func validateUsedBecomesInvalid() async {
    let api = baseAPI(onValidateInvitation: { _ in
      throw APIClientError.http(status: 409, message: nil, error: "used")
    })
    let (store, _, _) = makeStore(api)
    await store.submitInviteLink(link)
    #expect(store.phase == .invalid(.used))
  }

  @Test func validateTransportBecomesNetworkInvalid() async {
    let api = baseAPI(onValidateInvitation: { _ in throw APIClientError.transport("offline") })
    let (store, _, _) = makeStore(api)
    await store.submitInviteLink(link)
    #expect(store.phase == .invalid(.network("offline")))
  }

  @Test func createAccountSuccessEstablishesSession() async {
    let api = baseAPI(onSignup: { body in
      #expect(body.token == "INVITE-TOK")
      #expect(body.password == "1234")
      return SignupResponse(token: "session-jwt", user: sampleUser(username: "newbie"))
    })
    let (store, auth, tokens) = makeStore(api)
    await store.submitInviteLink(link)
    await store.createAccount(pin: "1234")
    #expect(auth.state == .signedIn(sampleUser(username: "newbie")))
    #expect(tokens.stored == "session-jwt")
  }

  @Test func createAccountConflictBecomesInvalidUsed() async {
    let api = baseAPI(onSignup: { _ in
      throw APIClientError.http(status: 409, message: nil, error: "already used")
    })
    let (store, auth, _) = makeStore(api)
    await store.submitInviteLink(link)
    await store.createAccount(pin: "1234")
    #expect(store.phase == .invalid(.used))
    #expect(auth.state == .signedOut)
  }

  @Test func createAccountTransportReturnsToReadyWithError() async {
    let api = baseAPI(onSignup: { _ in throw APIClientError.transport("offline") })
    let (store, _, _) = makeStore(api)
    await store.submitInviteLink(link)
    await store.createAccount(pin: "1234")
    #expect(store.phase == .ready(username: "newbie"))
    #expect(store.submitError != nil)
  }

  @Test func validateRejectedResponseBecomesInvalidBadToken() async {
    let api = baseAPI(onValidateInvitation: { _ in
      ValidateInvitationResponse(valid: false, username: "", expiresAt: "")
    })
    let (store, _, _) = makeStore(api)
    await store.submitInviteLink(link)
    #expect(store.phase == .invalid(.badToken))
  }

  @Test func validateServerErrorBecomesInvalidBadToken() async {
    let api = baseAPI(onValidateInvitation: { _ in
      throw APIClientError.http(status: 503, message: nil, error: "unavailable")
    })
    let (store, _, _) = makeStore(api)
    await store.submitInviteLink(link)
    #expect(store.phase == .invalid(.badToken))
  }

  @Test func resetReturnsToAwaitingToken() async {
    let (store, _, _) = makeStore(baseAPI())
    await store.submitInviteLink(link)
    store.reset()
    #expect(store.phase == .awaitingToken)
    #expect(store.pasteError == nil)
    #expect(store.submitError == nil)
  }

  /// A validation response that arrives AFTER `reset()` (sheet cancelled + reopened mid-flight)
  /// must be discarded — otherwise the stale `.ready` would drag the freshly-reset paste screen
  /// forward to PIN entry for an abandoned invitation, with `token` already cleared.
  @Test func staleValidationAfterResetIsDiscarded() async {
    let box = StoreBox()
    let api = baseAPI(onValidateInvitation: { _ in
      await box.store?.reset()  // simulate reset() racing in while validation is in flight
      return ValidateInvitationResponse(valid: true, username: "newbie", expiresAt: "t")
    })
    let (store, _, _) = makeStore(api)
    box.store = store
    await store.submitInviteLink(link)
    // The post-`await` generation guard drops the stale result; reset()'s state stands.
    #expect(store.phase == .awaitingToken)
  }
}
