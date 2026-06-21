# Invitation Signup (F2.5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a newly invited family member paste their invitation link, validate the token, choose a 4-digit PIN, and be signed straight in — entirely on-device.

**Architecture:** Mirror the web `signup.tsx` route as a four-state flow. Networking adds two unauthenticated calls (`validateInvitation`, `signup`) to the existing `AuthAPI`/`PortalAPIClient`. A new testable `@MainActor @Observable InvitationSignupStore` in SlipStreamKit owns the phase machine + error mapping and commits the session through a new `AuthStore.establishSession` (the same finalize path `signIn` uses). A new `InvitationSignupView` in Feature-Auth renders the phases, reusing `PINEntryField`, presented as a sheet from `SignInView`.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager, Swift Testing (`@Test`/`#expect`/`@Suite`), URLSession. No new third-party dependencies.

## Global Constraints

- iOS/iPadOS 26, Swift 6, `swift-tools-version: 6.2`. One adaptive SwiftUI layer for iPhone/iPad/Mac; do not branch on platform.
- **No new third-party dependencies.** All models already exist (F1.3): `ValidateInvitationResponse`, `SignupRequest`, `SignupResponse`.
- PIN is **exactly 4 digits** (client-enforced; the server accepts any non-empty password).
- Portal endpoints live under base path `/api/v1/requests` (`APIBase.portal`). Signup/validate are **tokenless** (no `Authorization` header).
- Kit logic is tested **headless via `swift test`** (the gate). App/Feature-Auth builds and on-device runs use **XcodeBuildMCP** — never shell out to `xcodebuild`.
- Force-dark theme is already global (`.preferredColorScheme(.dark)` at the app root); new views inherit it.
- Never inline-disable a linter rule. Run `make format` before committing; the pre-commit hook checks staged files.
- When spawning subagents, prefix labels with the model name in brackets (e.g. `[Opus (1M)] …`).
- Squash-merge to `main`; run `/code-review` before merging non-`docs/` changes.

---

### Task 1: Networking — query support + `validateInvitation` / `signup`

Add query-string support to `PortalAPIClient` (needed because `validateInvitation` passes the base64-URL token as `?token=…`, and `appendingPathComponent` would mangle a query baked into the path), then add the two new `AuthAPI` methods. All three conformers (`PortalAPIClient`, the test `FakeAuthAPI`) are updated in one commit so the build stays green.

**Files:**
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift` (perform/send/sendNoContent + AuthAPI extension)
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/AuthAPI.swift` (protocol)
- Modify: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/Fakes.swift` (`FakeAuthAPI` conformance)
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift`

**Interfaces:**
- Consumes: existing `PortalAPIClient.send/perform`, `APIClientError`, `ValidateInvitationResponse`, `SignupRequest`, `SignupResponse`, `StubURLProtocol`.
- Produces:
  - `AuthAPI.validateInvitation(token: String) async throws -> ValidateInvitationResponse`
  - `AuthAPI.signup(_ body: SignupRequest) async throws -> SignupResponse`
  - `PortalAPIClient.send(_:method:base:token:query:body:)` (new `query: [URLQueryItem]? = nil` param)

- [ ] **Step 1: Write the failing tests**

Add these three tests to `PortalAPIClientTests.swift` (inside the `PortalAPIClientTests` suite):

```swift
@Test func validateInvitationHitsPathWithEncodedTokenQuery() async throws {
  let token = "AbC-_123=="  // base64url-style: url-safe chars + padding
  StubURLProtocol.handler = { request in
    #expect(request.url?.path == "/api/v1/requests/auth/validate-invitation")
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
    #expect(items?.first(where: { $0.name == "token" })?.value == token)
    let body = #"{"valid":true,"username":"newbie","expiresAt":"2026-06-27T10:30:00Z"}"#
    let resp = HTTPURLResponse(
      url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    return (resp, Data(body.utf8))
  }
  let resp = try await client().validateInvitation(token: token)
  #expect(resp.valid == true)
  #expect(resp.username == "newbie")
}

@Test func validateInvitationMaps410ToHttpError() async throws {
  StubURLProtocol.handler = { request in
    let resp = HTTPURLResponse(
      url: request.url!, statusCode: 410, httpVersion: nil, headerFields: nil)!
    return (resp, Data(#"{"error":"invitation has expired"}"#.utf8))
  }
  await #expect(
    throws: APIClientError.http(status: 410, message: nil, error: "invitation has expired")
  ) {
    _ = try await client().validateInvitation(token: "expired")
  }
}

@Test func signupPostsToSignupPathAndDecodes() async throws {
  StubURLProtocol.handler = { request in
    #expect(request.url?.path == "/api/v1/requests/auth/signup")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    let body = """
      {"token":"session-jwt",
       "user":{"id":7,"username":"newbie","moduleSettings":[],
               "autoApprove":false,"enabled":true,"isAdmin":false,
               "createdAt":"t","updatedAt":"t"}}
      """
    let resp = HTTPURLResponse(
      url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
    return (resp, Data(body.utf8))
  }
  let resp = try await client().signup(SignupRequest(token: "invite-tok", password: "1234"))
  #expect(resp.token == "session-jwt")
  #expect(resp.user.username == "newbie")
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/SlipStreamKit --filter "validateInvitation|signupPostsToSignupPath"`
Expected: FAIL — `value of type 'PortalAPIClient' has no member 'validateInvitation'` / `'signup'` (compile error).

- [ ] **Step 3: Add query support to `perform`, `send`, and `sendNoContent`**

In `PortalAPIClient.swift`, replace the `perform` method's URL-building lines and signature. The current signature/opening is:

```swift
  private func perform(
    _ path: String,
    method: HTTPMethod,
    base: APIBase,
    token: String?,
    body: Data?
  ) async throws -> Data {
    let url =
      baseURL
      .appendingPathComponent(base.pathPrefix)
      .appendingPathComponent(path)
    var request = URLRequest(url: url)
```

Replace it with (adds `query:` param + URLComponents query assembly):

```swift
  private func perform(
    _ path: String,
    method: HTTPMethod,
    base: APIBase,
    token: String?,
    query: [URLQueryItem]?,
    body: Data?
  ) async throws -> Data {
    var url =
      baseURL
      .appendingPathComponent(base.pathPrefix)
      .appendingPathComponent(path)
    if let query, !query.isEmpty {
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      components?.queryItems = query
      if let urlWithQuery = components?.url {
        url = urlWithQuery
      }
    }
    var request = URLRequest(url: url)
```

Then update `send` to accept and forward `query`. Replace:

```swift
  public func send<T: Decodable>(
    _ path: String,
    method: HTTPMethod = .get,
    base: APIBase = .portal,
    token: String? = nil,
    body: Data? = nil
  ) async throws -> T {
    let data = try await perform(path, method: method, base: base, token: token, body: body)
```

with:

```swift
  public func send<T: Decodable>(
    _ path: String,
    method: HTTPMethod = .get,
    base: APIBase = .portal,
    token: String? = nil,
    query: [URLQueryItem]? = nil,
    body: Data? = nil
  ) async throws -> T {
    let data = try await perform(
      path, method: method, base: base, token: token, query: query, body: body)
```

Then update `sendNoContent`'s `perform` call. Replace:

```swift
  ) async throws {
    _ = try await perform(path, method: method, base: base, token: token, body: body)
  }
```

with:

```swift
  ) async throws {
    _ = try await perform(
      path, method: method, base: base, token: token, query: nil, body: body)
  }
```

- [ ] **Step 4: Add the two protocol methods**

In `AuthAPI.swift`, replace the protocol body:

```swift
/// The auth surface AuthStore depends on. Backed by PortalAPIClient; faked in tests.
public protocol AuthAPI: Sendable {
  func login(_ body: LoginRequest) async throws -> LoginResponse
  func profile(token: String) async throws -> PortalUser
  /// Validate an invitation token (tokenless). Throws `APIClientError.http(404/410/409)`
  /// for not-found / expired / already-used.
  func validateInvitation(token: String) async throws -> ValidateInvitationResponse
  /// Redeem an invitation with a new PIN (tokenless). Returns the session `{token, user}`.
  func signup(_ body: SignupRequest) async throws -> SignupResponse
}
```

- [ ] **Step 5: Implement both methods on `PortalAPIClient`**

In `PortalAPIClient.swift`, extend the `extension PortalAPIClient: AuthAPI` block (add after `profile`):

```swift
  public func validateInvitation(token: String) async throws -> ValidateInvitationResponse {
    try await send(
      "auth/validate-invitation",
      method: .get,
      base: .portal,
      token: nil,
      query: [URLQueryItem(name: "token", value: token)]
    )
  }

  public func signup(_ body: SignupRequest) async throws -> SignupResponse {
    let encoded = try JSONEncoder().encode(body)
    return try await send("auth/signup", method: .post, base: .portal, token: nil, body: encoded)
  }
```

- [ ] **Step 6: Update `FakeAuthAPI` to conform**

In `Fakes.swift`, replace the `FakeAuthAPI` struct:

```swift
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
```

(The two new closures have defaults, so existing `FakeAuthAPI(onLogin:onProfile:)` call sites in `AuthStoreTests.swift` keep compiling unchanged.)

- [ ] **Step 7: Run the tests to verify they pass**

Run: `swift test --package-path Packages/SlipStreamKit --filter "validateInvitation|signupPostsToSignupPath"`
Expected: PASS (3 tests). Then run the full suite to confirm nothing regressed:
Run: `swift test --package-path Packages/SlipStreamKit`
Expected: PASS, all green (prior 112 + 3 new = 115).

- [ ] **Step 8: Format & commit**

```bash
make format
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift \
        Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/AuthAPI.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/Fakes.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift
git commit -m "feat(kit): AuthAPI validateInvitation + signup, client query support (F2.5)"
```

---

### Task 2: `InviteLinkParser`

A pure parser that pulls `(serverURL, token)` from a pasted full invite link, or treats a bare token against an already-configured server.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Invitation/InviteLinkParser.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/InviteLinkParserTests.swift`

(`SlipStreamKit/Package.swift` globs `Sources/SlipStreamKit/**`, so the new `Invitation/` folder needs no manifest change.)

**Interfaces:**
- Produces:
  - `InviteLinkParser.Result` — `{ let serverURL: URL; let token: String }`, `Equatable, Sendable`.
  - `InviteLinkParser.parse(_ input: String, configuredServer: URL?) -> InviteLinkParser.Result?`

- [ ] **Step 1: Write the failing tests**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/InviteLinkParserTests.swift`:

```swift
import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct InviteLinkParserTests {
  let server = URL(string: "https://slipstream.example.com")!

  @Test func parsesFullLinkOriginAndToken() {
    let r = InviteLinkParser.parse(
      "https://invite.example.com/signup?token=ABC123", configuredServer: nil)
    #expect(r?.serverURL == URL(string: "https://invite.example.com")!)
    #expect(r?.token == "ABC123")
  }

  @Test func parsesLinkWithTrailingSlashAndFragment() {
    let r = InviteLinkParser.parse(
      "https://host.example.com/signup/?token=XYZ#welcome", configuredServer: nil)
    #expect(r?.serverURL == URL(string: "https://host.example.com")!)
    #expect(r?.token == "XYZ")
  }

  @Test func parsesLinkWithPortPreservingOrigin() {
    let r = InviteLinkParser.parse(
      "http://localhost:8080/signup?token=DEVTOK", configuredServer: nil)
    #expect(r?.serverURL == URL(string: "http://localhost:8080")!)
    #expect(r?.token == "DEVTOK")
  }

  @Test func bareTokenUsesConfiguredServer() {
    let r = InviteLinkParser.parse("BARE-TOKEN-123", configuredServer: server)
    #expect(r?.serverURL == server)
    #expect(r?.token == "BARE-TOKEN-123")
  }

  @Test func bareTokenWithoutServerIsNil() {
    #expect(InviteLinkParser.parse("BARE-TOKEN-123", configuredServer: nil) == nil)
  }

  @Test func garbageWithWhitespaceIsNil() {
    #expect(InviteLinkParser.parse("not a token", configuredServer: server) == nil)
  }

  @Test func linkWithoutTokenQueryIsNil() {
    #expect(
      InviteLinkParser.parse("https://host.example.com/signup", configuredServer: server) == nil)
  }

  @Test func blankIsNil() {
    #expect(InviteLinkParser.parse("   ", configuredServer: server) == nil)
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/SlipStreamKit --filter InviteLinkParserTests`
Expected: FAIL — `cannot find 'InviteLinkParser' in scope`.

- [ ] **Step 3: Write the parser**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Invitation/InviteLinkParser.swift`:

```swift
import Foundation

/// Pulls a server origin + invitation token out of a pasted invitation. Accepts a full
/// `https://host/…/signup?token=…` URL (used to bootstrap the server origin for a brand-new
/// user) or, when a server is already configured, a bare token string.
public enum InviteLinkParser {
  public struct Result: Equatable, Sendable {
    public let serverURL: URL
    public let token: String
    public init(serverURL: URL, token: String) {
      self.serverURL = serverURL
      self.token = token
    }
  }

  /// Returns `nil` when the input is neither a `http(s)` URL carrying a non-empty `token`
  /// query item nor (with `configuredServer` set) a plain whitespace-free bare token.
  public static func parse(_ input: String, configuredServer: URL?) -> Result? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if let components = URLComponents(string: trimmed),
      let scheme = components.scheme?.lowercased(),
      scheme == "https" || scheme == "http",
      let host = components.host, !host.isEmpty,
      let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
      !token.isEmpty
    {
      var origin = URLComponents()
      origin.scheme = scheme
      origin.host = host
      origin.port = components.port
      if let url = origin.url {
        return Result(serverURL: url, token: token)
      }
    }

    // Bare token: only meaningful when we already know which server to hit, and only when the
    // input is a plain token (no scheme, no whitespace) rather than a malformed/partial URL.
    if let configuredServer,
      !trimmed.contains(where: \.isWhitespace),
      URLComponents(string: trimmed)?.scheme == nil
    {
      return Result(serverURL: configuredServer, token: trimmed)
    }

    return nil
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/SlipStreamKit --filter InviteLinkParserTests`
Expected: PASS (8 tests).

- [ ] **Step 5: Format & commit**

```bash
make format
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Invitation/InviteLinkParser.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/InviteLinkParserTests.swift
git commit -m "feat(kit): InviteLinkParser (full-link → origin+token, bare-token fallback) (F2.5)"
```

---

### Task 3: `AuthStore.establishSession`

Extract the session-commit side effects into a public method `signIn` also routes through, so invitation signup commits a session identically.

**Files:**
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/AuthStore.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/AuthStoreTests.swift`

**Interfaces:**
- Consumes: `TokenStore`, `ServerConfigStore`, `LastUsernameStore`, `PortalUser`.
- Produces: `AuthStore.establishSession(serverURL: URL, token: String, user: PortalUser, username: String) throws` — saves the JWT, persists the server URL + remembered username, sets `state = .signedIn(user)`; throws if the keychain save fails.

- [ ] **Step 1: Write the failing test**

Add to `AuthStoreTests.swift` (inside the `AuthStoreTests` suite):

```swift
@Test func establishSessionStoresTokenConfigUsernameAndSignsIn() throws {
  let api = FakeAuthAPI(
    onLogin: { _ in throw APIClientError.transport("x") },
    onProfile: { _ in sampleUser() }
  )
  let tokens = FakeTokenStore()
  let config = FakeServerConfigStore()
  let remembered = FakeLastUsernameStore()
  let store = makeStore(api: api, tokenStore: tokens, config: config, lastUsername: remembered)

  try store.establishSession(
    serverURL: serverURL, token: "newtok",
    user: sampleUser(username: "newbie"), username: "newbie")

  #expect(store.state == .signedIn(sampleUser(username: "newbie")))
  #expect(store.currentToken == "newtok")
  #expect(tokens.stored == "newtok")
  #expect(config.baseURL == serverURL)
  #expect(remembered.lastUsername == "newbie")
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --package-path Packages/SlipStreamKit --filter establishSessionStoresTokenConfigUsernameAndSignsIn`
Expected: FAIL — `value of type 'AuthStore' has no member 'establishSession'`.

- [ ] **Step 3: Add `establishSession` and route `signIn` through it**

In `AuthStore.swift`, replace the success block inside `signIn` — these five lines:

```swift
      try tokenStore.save(resp.token)
      serverConfig.setBaseURL(serverURL)
      lastUsernameStore.setLastUsername(username)
      token = resp.token
      state = .signedIn(resp.user)
```

with:

```swift
      try establishSession(
        serverURL: serverURL, token: resp.token, user: resp.user, username: username)
```

Then add the new method immediately after `signIn` (before `signOut`):

```swift
  /// Commit a session created out-of-band (e.g. invitation signup, F2.5), applying the same
  /// side effects as a successful sign-in: persist the JWT + server URL + remembered username
  /// and flip to `.signedIn`. `signIn` routes through this too, so both paths are identical.
  /// Throws if the keychain save fails; the caller maps it to a user-facing error.
  public func establishSession(
    serverURL: URL, token newToken: String, user: PortalUser, username: String
  ) throws {
    try tokenStore.save(newToken)
    serverConfig.setBaseURL(serverURL)
    lastUsernameStore.setLastUsername(username)
    token = newToken
    state = .signedIn(user)
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/SlipStreamKit --filter AuthStoreTests`
Expected: PASS — the new test plus all existing `AuthStoreTests` (signIn still green, proving the refactor preserved behavior).

- [ ] **Step 5: Format & commit**

```bash
make format
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/AuthStore.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/AuthStoreTests.swift
git commit -m "feat(kit): AuthStore.establishSession (shared signIn/signup finalize) (F2.5)"
```

---

### Task 4: `InvitationSignupStore`

The testable heart: a `@MainActor @Observable` phase machine that parses → validates → creates the account, mapping every server status to a phase and committing the session via `AuthStore.establishSession`.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Invitation/InvitationSignupStore.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/InvitationSignupStoreTests.swift`

**Interfaces:**
- Consumes: `AuthAPI.validateInvitation/signup` (Task 1), `InviteLinkParser` (Task 2), `AuthStore.establishSession` (Task 3), `ServerConfigStore`, `APIClientError`.
- Produces:
  - `InvitationSignupStore.InvalidReason` — `.notFound | .expired | .used | .badToken | .network(String)`, `Equatable, Sendable`.
  - `InvitationSignupStore.Phase` — `.awaitingToken | .validating | .invalid(InvalidReason) | .ready(username: String) | .creatingAccount`, `Equatable, Sendable`.
  - `init(makeAuthAPI: @escaping @Sendable (URL) -> AuthAPI, serverConfig: ServerConfigStore, auth: AuthStore)`
  - `var phase: Phase` (read-only), `var pasteError: String?`, `var submitError: String?`
  - `func submitInviteLink(_ pasted: String) async`, `func retryValidation() async`, `func createAccount(pin: String) async`, `func reset()`

- [ ] **Step 1: Write the failing tests**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/InvitationSignupStoreTests.swift`:

```swift
import Foundation
import Testing

@testable import SlipStreamKit

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

  private func validResponse(username: String = "newbie") -> ValidateInvitationResponse {
    ValidateInvitationResponse(valid: true, username: username, expiresAt: "2026-06-27T10:30:00Z")
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

  @Test func resetReturnsToAwaitingToken() async {
    let (store, _, _) = makeStore(baseAPI())
    await store.submitInviteLink(link)
    store.reset()
    #expect(store.phase == .awaitingToken)
    #expect(store.pasteError == nil)
    #expect(store.submitError == nil)
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/SlipStreamKit --filter InvitationSignupStoreTests`
Expected: FAIL — `cannot find 'InvitationSignupStore' in scope`.

- [ ] **Step 3: Write the store**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Invitation/InvitationSignupStore.swift`:

```swift
import Foundation
import Observation

/// Drives invitation signup (F2.5): parse a pasted link, validate the token, choose a PIN,
/// and commit the session. Mirrors the web `signup.tsx` four-state route. UI binds to `phase`.
@MainActor
@Observable
public final class InvitationSignupStore {
  public enum InvalidReason: Equatable, Sendable {
    case notFound, expired, used, badToken
    case network(String)
  }

  public enum Phase: Equatable, Sendable {
    case awaitingToken
    case validating
    case invalid(InvalidReason)
    case ready(username: String)
    case creatingAccount
  }

  public private(set) var phase: Phase = .awaitingToken
  /// Inline error on the paste screen (unparseable input); distinct from `.invalid`,
  /// which means the server rejected an otherwise well-formed token.
  public private(set) var pasteError: String?
  /// Transient error shown on the create-PIN screen after a recoverable signup failure
  /// (e.g. network) — the phase returns to `.ready` so the user can retry.
  public private(set) var submitError: String?

  private let makeAuthAPI: @Sendable (URL) -> AuthAPI
  private let serverConfig: ServerConfigStore
  private let auth: AuthStore

  private var serverURL: URL?
  private var token: String?
  private var validatedUsername: String?

  public init(
    makeAuthAPI: @escaping @Sendable (URL) -> AuthAPI,
    serverConfig: ServerConfigStore,
    auth: AuthStore
  ) {
    self.makeAuthAPI = makeAuthAPI
    self.serverConfig = serverConfig
    self.auth = auth
  }

  /// Parse a pasted invitation (full link → origin + token, or a bare token when a server is
  /// already configured), then validate it. Unparseable input keeps the paste screen up.
  public func submitInviteLink(_ pasted: String) async {
    pasteError = nil
    submitError = nil
    guard let parsed = InviteLinkParser.parse(pasted, configuredServer: serverConfig.baseURL)
    else {
      phase = .awaitingToken
      pasteError = "That doesn't look like a valid invitation link."
      return
    }
    serverURL = parsed.serverURL
    token = parsed.token
    await runValidation()
  }

  /// Re-run validation against the already-parsed token (the Retry affordance on a network failure).
  public func retryValidation() async {
    await runValidation()
  }

  private func runValidation() async {
    guard let serverURL, let token else { return }
    phase = .validating
    do {
      let resp = try await makeAuthAPI(serverURL).validateInvitation(token: token)
      if resp.valid {
        validatedUsername = resp.username
        phase = .ready(username: resp.username)
      } else {
        phase = .invalid(.badToken)
      }
    } catch let APIClientError.http(status, _, _) {
      phase = .invalid(Self.invalidReason(forStatus: status))
    } catch let APIClientError.transport(message) {
      phase = .invalid(.network(message))
    } catch let APIClientError.decoding(message) {
      phase = .invalid(.network(message))
    } catch {
      phase = .invalid(.network(String(describing: error)))
    }
  }

  /// Redeem the invitation with the chosen 4-digit PIN and, on success, commit the returned
  /// session through `AuthStore` (auto-sign-in). A consumed/expired/missing invite becomes
  /// `.invalid`; a recoverable failure returns to `.ready` with `submitError`.
  public func createAccount(pin: String) async {
    submitError = nil
    guard let serverURL, let token, let username = validatedUsername else { return }
    phase = .creatingAccount
    do {
      let resp = try await makeAuthAPI(serverURL).signup(SignupRequest(token: token, password: pin))
      try auth.establishSession(
        serverURL: serverURL, token: resp.token, user: resp.user, username: resp.user.username)
      // Session committed; AuthGateView swaps the signed-out tree (and this sheet) away.
    } catch let APIClientError.http(status, _, _) where status == 409 || status == 410
      || status == 404
    {
      phase = .invalid(Self.invalidReason(forStatus: status))
    } catch let APIClientError.http {
      submitError = "Couldn't create your account. Please try again."
      phase = .ready(username: username)
    } catch let APIClientError.transport {
      submitError = "Network error. Please try again."
      phase = .ready(username: username)
    } catch {
      submitError = "Couldn't create your account. Please try again."
      phase = .ready(username: username)
    }
  }

  /// Return to the paste screen and forget any in-flight invitation (used when the signup
  /// sheet is reopened or the user chooses to try another link).
  public func reset() {
    phase = .awaitingToken
    pasteError = nil
    submitError = nil
    serverURL = nil
    token = nil
    validatedUsername = nil
  }

  private static func invalidReason(forStatus status: Int) -> InvalidReason {
    switch status {
    case 404: return .notFound
    case 410: return .expired
    case 409: return .used
    default: return .badToken
    }
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/SlipStreamKit --filter InvitationSignupStoreTests`
Expected: PASS (10 tests). Then the full suite:
Run: `swift test --package-path Packages/SlipStreamKit`
Expected: PASS, all green.

- [ ] **Step 5: Format & commit**

```bash
make format
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Invitation/InvitationSignupStore.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/InvitationSignupStoreTests.swift
git commit -m "feat(kit): InvitationSignupStore phase machine (validate → PIN → session) (F2.5)"
```

---

### Task 5: `InvitationSignupView` + `SignInView` entry point

Render the four phases (reusing `PINEntryField`) and add the "Have an invitation?" entry on the sign-in screen. UI is verified by a successful `build_sim`; the behavior gate is the kit unit tests from Tasks 1–4. On-device verification happens in Task 6.

**Files:**
- Create: `Packages/Feature-Auth/Sources/FeatureAuth/InvitationSignupView.swift`
- Modify: `Packages/Feature-Auth/Sources/FeatureAuth/SignInView.swift`

(`Feature-Auth/Package.swift` globs `Sources/FeatureAuth/**`; the new file needs no manifest change. `PINEntryField` and `InvitationSignupStore` are both visible here — `PINEntryField` is in this module, `InvitationSignupStore` via the existing `import SlipStreamKit`.)

**Interfaces:**
- Consumes: `InvitationSignupStore` (Task 4) from the environment, `PINEntryField` (same module).
- Produces: `public struct InvitationSignupView: View` with `public init()`.

- [ ] **Step 1: Create the view**

Create `Packages/Feature-Auth/Sources/FeatureAuth/InvitationSignupView.swift`:

```swift
import SlipStreamKit
import SwiftUI

/// The invitation-redemption flow (F2.5): paste an invite link, validate it, choose a 4-digit
/// PIN, and get signed in. Presented as a sheet from `SignInView`; driven entirely by
/// `InvitationSignupStore.phase`.
public struct InvitationSignupView: View {
  @Environment(InvitationSignupStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var pasteText = ""
  @State private var pin = ""
  @FocusState private var pinFocused: Bool

  public init() {}

  public var body: some View {
    NavigationStack {
      Group {
        switch store.phase {
        case .awaitingToken: awaitingTokenView
        case .validating: validatingView
        case .invalid(let reason): invalidView(reason)
        case .ready(let username): createPINView(username: username)
        case .creatingAccount: creatingAccountView
        }
      }
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .navigationTitle("Sign Up")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }

  // MARK: No token — paste screen

  private var awaitingTokenView: some View {
    VStack(spacing: 16) {
      Image(systemName: "envelope.open")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("Have an invitation?")
        .font(.title2.bold())
      Text("Paste the invitation link you were sent to create your account.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      TextField("https://…/signup?token=…", text: $pasteText, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .textContentType(.URL)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .lineLimit(1...3)
      PasteButton(payloadType: String.self) { items in
        if let first = items.first {
          pasteText = first.trimmingCharacters(in: .whitespacesAndNewlines)
        }
      }
      if let error = store.pasteError {
        Text(error).font(.footnote).foregroundStyle(.red)
      }
      Button {
        Task { await store.submitInviteLink(pasteText) }
      } label: {
        Text("Continue").frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }

  // MARK: Validating

  private var validatingView: some View {
    VStack(spacing: 16) {
      ProgressView()
      Text("Validating invitation…").foregroundStyle(.secondary)
    }
    .frame(maxHeight: .infinity)
  }

  // MARK: Invalid / expired

  private func invalidView(_ reason: InvitationSignupStore.InvalidReason) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text(invalidTitle(reason)).font(.title2.bold())
      Text(invalidMessage(reason))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      if case .network = reason {
        Button("Retry") { Task { await store.retryValidation() } }
          .buttonStyle(.borderedProminent)
      }
      Button("Try Another Link") {
        pasteText = ""
        store.reset()
      }
    }
  }

  private func invalidTitle(_ reason: InvitationSignupStore.InvalidReason) -> String {
    switch reason {
    case .network: "Connection Problem"
    default: "Invalid Invitation"
    }
  }

  private func invalidMessage(_ reason: InvitationSignupStore.InvalidReason) -> String {
    switch reason {
    case .expired: "This invitation has expired. Ask your admin for a new link."
    case .used: "This invitation has already been used. Ask your admin for a new link."
    case .notFound, .badToken: "This invitation link is invalid. Ask your admin for a new link."
    case .network: "Couldn't reach the server. Check your connection and try again."
    }
  }

  // MARK: Create PIN

  private func createPINView(username: String) -> some View {
    VStack(spacing: 16) {
      Text("Welcome, \(username)!").font(.title2.bold())
      Text("Create a 4-digit PIN to secure your account.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      PINEntryField(pin: $pin, isFocused: $pinFocused)
        .onChange(of: pin) { _, newValue in maybeSubmit(pin: newValue) }
      if let error = store.submitError {
        Text(error).font(.footnote).foregroundStyle(.red)
      }
    }
    .onAppear { pinFocused = true }
  }

  private var creatingAccountView: some View {
    VStack(spacing: 16) {
      ProgressView()
      Text("Creating your account…").foregroundStyle(.secondary)
    }
    .frame(maxHeight: .infinity)
  }

  // MARK: Submit

  /// Auto-submit once the PIN is complete (mirrors the web `pin.length === 4` effect and
  /// `SignInView`'s focus-gated auto-submit). On a recoverable failure we're back on `.ready`,
  /// so clear the PIN to retype; on success the auth gate swaps this whole sheet away.
  private func maybeSubmit(pin newValue: String) {
    guard pinFocused, newValue.count == 4 else { return }
    Task {
      await store.createAccount(pin: newValue)
      if case .ready = store.phase { pin = "" }
    }
  }
}
```

- [ ] **Step 2: Add the entry point to `SignInView`**

In `SignInView.swift`, add two stored properties after `@FocusState private var pinFocused: Bool` (line 16):

```swift
  @Environment(InvitationSignupStore.self) private var signupStore
  @State private var showingSignup = false
```

Then add a new section in `body` — insert it after the Sign In `Section { … }` block (after line 34's closing of that section, before the `Form`'s closing brace at line 35):

```swift
      Section {
        Button("Have an invitation? Sign up") {
          signupStore.reset()
          showingSignup = true
        }
      }
```

Then add the sheet modifier on the `Form` — change the `.onAppear(perform: populateIfNeeded)` line (line 36) to:

```swift
    .onAppear(perform: populateIfNeeded)
    .sheet(isPresented: $showingSignup) {
      InvitationSignupView()
    }
```

- [ ] **Step 3: Build to verify it compiles**

Build the app for the iPhone 17 simulator via XcodeBuildMCP (scheme `SlipStream`): call `mcp__xcodebuildmcp__build_sim` (confirm session defaults first with `mcp__xcodebuildmcp__session_show_defaults`).
Expected: BUILD SUCCEEDED. (FeatureAuth fails to build if `InvitationSignupStore` isn't injected — that wiring is Task 6, but the *view* compiles standalone because it reads the store from the environment at runtime, not compile time.)

- [ ] **Step 4: Format & commit**

```bash
make format
git add Packages/Feature-Auth/Sources/FeatureAuth/InvitationSignupView.swift \
        Packages/Feature-Auth/Sources/FeatureAuth/SignInView.swift
git commit -m "feat(auth): InvitationSignupView + sign-in entry point (F2.5)"
```

---

### Task 6: App composition + on-device verification

Compose `InvitationSignupStore` at the app root and inject it so `SignInView`'s sheet resolves it, then verify the flow on-device.

**Files:**
- Modify: `App/SlipStreamApp.swift`

**Interfaces:**
- Consumes: `InvitationSignupStore` (Task 4), the existing `onUnauthorized` handler + `UserDefaultsServerConfigStore` + `initialAuth`.
- Produces: an `InvitationSignupStore` in the environment for the signed-out subtree.

- [ ] **Step 1: Build the store in `init` and inject it**

In `SlipStreamApp.swift`, add a stored property after `@State private var poller: PollingEngine` (line 9):

```swift
  @State private var signup: InvitationSignupStore
```

In `init()`, after the `expiry.poller = initialPoller` line (line 48), add (it reuses the same hook-wired client factory and the shared server-config key, and references `initialAuth` for the session commit):

```swift
    let initialSignup = InvitationSignupStore(
      makeAuthAPI: { url in PortalAPIClient(baseURL: url, onUnauthorized: onUnauthorized) },
      serverConfig: UserDefaultsServerConfigStore(),
      auth: initialAuth
    )
```

Then after `_poller = State(initialValue: initialPoller)` (line 52), add:

```swift
    _signup = State(initialValue: initialSignup)
```

Then in `body`, add the environment injection on `RootView()` — after `.environment(posterSize)` (line 62):

```swift
        .environment(signup)
```

- [ ] **Step 2: Build to verify it compiles**

Build for the iPhone 17 simulator via `mcp__xcodebuildmcp__build_sim` (scheme `SlipStream`).
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run the full kit test suite once more**

Run: `swift test --package-path Packages/SlipStreamKit`
Expected: PASS, all green (≈ 112 baseline + 22 new across Tasks 1–4: 3 client + 8 parser + 1 establishSession + 10 store).

- [ ] **Step 4: On-device verification (live `--dev-mode` server)**

Use the `test-with-dev-server` skill to run the app against the local dev server (start it, launch the app on iPhone 17). Verify:

1. **Entry + paste screen:** On the signed-out sign-in screen, tap **"Have an invitation? Sign up"** → the sheet opens on the paste screen (envelope icon, link field, Continue disabled while empty).
2. **Invalid path (always reachable against the live server):** Configure the dev server in the sign-in field first (so the bare-token path has an origin), open the sheet, paste a bogus token like `not-a-real-token`, tap Continue → spinner → **"Invalid Invitation"** with "Ask your admin for a new link" + "Try Another Link". This exercises the live `validate-invitation` 404 path end-to-end.
3. **Happy path (if a real invite is obtainable):** If you can mint a real invitation from the SlipStream server side (admin web/API or a DB insert on the dev server), paste the full `https://…/signup?token=…` link → spinner → **"Welcome, {username}!"** → type a 4-digit PIN → auto-submits → lands in the app shell (signed in). If minting an invite is impractical, the Task 1–4 unit tests are the gate (per the F1.5 / F2.4 precedent for paths that need server-side state that's hard to fabricate), and record that the happy path was covered by unit tests + the verified invalid path.

Capture a screenshot of the paste screen and the invalid state (`mcp__xcodebuildmcp__screenshot`).

- [ ] **Step 5: Format & commit**

```bash
make format
git add App/SlipStreamApp.swift
git commit -m "feat(app): compose + inject InvitationSignupStore (F2.5)"
```

- [ ] **Step 6: Update the tracker**

Mark F2.5 done in `docs/TRACKER.md` (line 37): change `[ ] **F2.5**` to `[x] **F2.5**` and append a one-line completion note + plan link, matching the style of the F2.4 entry. Add a Plans-section bullet referencing `docs/superpowers/plans/2026-06-20-invitation-signup.md`. Commit:

```bash
git add docs/TRACKER.md
git commit -m "docs(f2.5): mark invitation signup complete"
```

---

## Done criteria

- `swift test --package-path Packages/SlipStreamKit` passes, all green, with new coverage for: client query encoding, `validateInvitation`/`signup` request shapes + error mapping, `InviteLinkParser`, `AuthStore.establishSession`, and the full `InvitationSignupStore` phase machine.
- `mcp__xcodebuildmcp__build_sim` succeeds for scheme `SlipStream`.
- On-device: the sign-in entry opens the paste sheet; a bogus token reaches the live "Invalid Invitation" state; the happy path lands in the shell (or is documented as unit-test-gated if a live invite can't be minted).
- `/code-review` run and findings triaged before squash-merge to `main`.
