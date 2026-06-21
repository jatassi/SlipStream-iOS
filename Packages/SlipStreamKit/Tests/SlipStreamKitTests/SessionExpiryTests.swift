import Foundation
import Testing

@testable import SlipStreamKit

@MainActor
@Suite struct SessionExpiryTests {
  let serverURL = URL(string: "https://slipstream.example.com")!

  /// A signed-in AuthStore backed by fakes, for exercising the handler end-to-end.
  private func makeSignedInAuth() async -> (AuthStore, FakeTokenStore) {
    let api = FakeAuthAPI(
      onLogin: { _ in LoginResponse(token: "tok", user: sampleUser(), isAdmin: false) },
      onProfile: { _ in sampleUser() }
    )
    let tokens = FakeTokenStore()
    let store = AuthStore(
      makeAuthAPI: { _ in api },
      tokenStore: tokens,
      serverConfig: FakeServerConfigStore(),
      lastUsernameStore: FakeLastUsernameStore()
    )
    await store.signIn(serverURL: serverURL, username: "jack", pin: "1234")
    return (store, tokens)
  }

  @Test func handleUnauthorizedSuspendsPollerAndSignsOut() async {
    let (auth, tokens) = await makeSignedInAuth()
    let poller = PollingEngine(scheduler: ParkingScheduler())
    poller.setActivity(.active)  // a running engine, so suspend has an observable effect

    let expiry = SessionExpiry()
    expiry.auth = auth
    expiry.poller = poller

    expiry.handleUnauthorized()

    #expect(auth.state == .signedOut)
    #expect(tokens.deleteCount == 1)
    #expect(poller.isSuspended)
  }

  @Test func handleUnauthorizedIsIdempotent() async {
    let (auth, tokens) = await makeSignedInAuth()
    let poller = PollingEngine(scheduler: ParkingScheduler())
    poller.setActivity(.active)

    let expiry = SessionExpiry()
    expiry.auth = auth
    expiry.poller = poller

    expiry.handleUnauthorized()
    expiry.handleUnauthorized()  // e.g. poll-path + client-hook for one expired token

    #expect(auth.state == .signedOut)
    #expect(tokens.deleteCount == 1)  // signOut() guarded — keychain deleted exactly once
    #expect(poller.isSuspended)
  }

  @Test func handleUnauthorizedWhenSignedOutIsNoOp() {
    // A late/duplicate 401 after we've already returned to PIN entry must NOT suspend the poller
    // (which only AppShellView.onAppear would later resume), nor re-run sign-out.
    let auth = AuthStore(
      makeAuthAPI: { _ in
        FakeAuthAPI(
          onLogin: { _ in throw APIClientError.transport("x") },
          onProfile: { _ in sampleUser() }
        )
      },
      tokenStore: FakeTokenStore(),
      serverConfig: FakeServerConfigStore(),
      lastUsernameStore: FakeLastUsernameStore()
    )
    let poller = PollingEngine(scheduler: ParkingScheduler())
    poller.setActivity(.active)

    let expiry = SessionExpiry()
    expiry.auth = auth
    expiry.poller = poller

    expiry.handleUnauthorized()

    #expect(auth.state == .signedOut)
    #expect(poller.isSuspended == false)  // never suspended — no live session to protect
  }

  @Test func handleUnauthorizedWithoutWiringDoesNotCrash() {
    // weak refs unset (or already deallocated) — the handler must be a safe no-op.
    let expiry = SessionExpiry()
    expiry.handleUnauthorized()
  }
}
