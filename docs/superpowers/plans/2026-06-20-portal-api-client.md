# Portal API Client (F1.2) — Finish Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the F1.2 *Portal API client* by extending Plan 1's `PortalAPIClient` with the reusable infrastructure every later feature depends on — multi-base URL targeting (`portal` / `metadata` / public `status`), `204`/empty-body handling, and a central `401` hook — so feature code never re-implements networking.

**Architecture:** This is a refinement of the existing `SlipStreamKit/Networking` layer, not a rewrite. Plan 1 shipped a `PortalAPIClient` (base `/api/v1/requests`, Bearer injection, typed `APIClientError`, JSON decode + `{message?,error?}` error mapping) conforming to `AuthAPI` (`login`/`profile`). We refactor its single internal `send<T>` into a private `perform(...) -> Data` core plus a **public** `send<T>` (decode) and a new public `sendNoContent` (204/empty), both taking an `APIBase` that selects one of three path prefixes. We add an injected `onUnauthorized` closure that fires on a `401` to a *token-bearing* request (mirroring the web's "only if a token was previously held" guard), giving the F2.4 session-expiry handler a seam to consume later. All work is pure Foundation, unit-tested headlessly with `swift test` against a `URLProtocol` stub — no network, no simulator, no app changes until the final verification build.

**Tech Stack:** Swift 6 (strict concurrency), Swift Package Manager (local path package), Swift Testing (`@Test`, `confirmation`), `URLSession` async/await, `URLProtocol` test stub. XcodeBuildMCP only for the final app-target compile check.

## Global Constraints

- **Language/mode:** Swift 6, strict concurrency (`swift-tools-version: 6.0`). Every type crossing a concurrency boundary is `Sendable`; the client is a `Sendable final class`.
- **Deployment target:** iOS/iPadOS **26.0** minimum; `SlipStreamKit` also targets **macOS 14** so these tests run via `swift test` on the Mac host.
- **Networking:** base URL is the user's **HTTPS** reverse-proxy origin. Portal base path is **`/api/v1/requests`**; the shared metadata group is **`/api/v1/metadata`**; the public status endpoint is **`/api/v1/status`**. Auth is `Authorization: Bearer <token>`. **Do not** add an ATS arbitrary-loads exception.
- **Contract source of truth:** `~/Git/SlipStream/web/src/api/portal/client.ts` (the `portalFetch` wrapper) and `internal/api/routes.go` (route mounts). Mirror behavior; do not invent endpoints or fields.
- **Fail fast — no retry/backoff** (resolves the spec's open question). The web `portalFetch` does not retry transient errors; v1 iOS matches it. A transport failure maps to `APIClientError.transport(_)` and surfaces to the caller immediately.
- **401 hook fires only when the request carried a token.** This mirrors the web client, which dispatches `auth:unauthorized` only if a token was already held (`web/src/api/portal/client.ts:40-43`). A bad-PIN login `401` (no token attached) therefore stays local to sign-in and never triggers a global logout.
- **Scope — client infrastructure only.** The per-resource endpoint methods (search / library / requests / inbox / notifications) belong to their own feature plans (F3.x / F4.x / F6.x), and their Codable models are F1.3. This plan delivers only the shared plumbing those features build on; multi-base support is proven here by tests, not by a concrete feature call.
- **Commits:** one per task minimum. Repo is already initialized; default branch is `main`. This is a solo repo — commit directly. Run `/code-review` before squash-merging the code tasks to `main` (Task 5).

---

## File structure (this plan)

```
Packages/SlipStreamKit/
  Sources/SlipStreamKit/Networking/
    HTTPMethod.swift          # CREATE — HTTPMethod enum (Task 1)
    APIBase.swift             # CREATE — APIBase enum + pathPrefix (Task 1)
    PortalAPIClient.swift     # MODIFY — perform/send multi-base (T1), sendNoContent (T2), onUnauthorized (T3)
    APIError.swift            # unchanged (already has http/decoding/transport)
    AuthAPI.swift             # unchanged
  Tests/SlipStreamKitTests/
    PortalAPIClientTests.swift  # MODIFY — Probe fixture + 7 new tests across T1–T3
    StubURLProtocol.swift       # unchanged (reused as-is)
docs/
  superpowers/specs/01-foundations/portal-api-client.md  # MODIFY — status + open questions (Task 4)
  TRACKER.md                                              # MODIFY — F1.2 → done (Task 4)
```

**No app-target changes.** `App/SlipStreamApp.swift` composes `PortalAPIClient(baseURL: url)`; the new `onUnauthorized` init parameter defaults to `nil`, so that call still compiles untouched. Wiring the hook into `AuthStore` is **F2.4's** job, not this plan's. Task 5 only *verifies* the app still links.

**External dependencies:** none added.

---

### Task 1: Multi-base URL construction (`HTTPMethod`, `APIBase`, public `send`)

Introduce typed HTTP verbs and the three API bases, then refactor the client's request core into a private `perform(...) -> Data` and a **public** `send<T>` that decodes. The portal calls (`login`/`profile`) keep working through the new signature; two new tests prove the `status` and `metadata` bases build the right URLs.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/HTTPMethod.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/APIBase.swift`
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift`

**Interfaces:**
- Consumes: `APIClientError` (existing), `LoginRequest`/`LoginResponse`/`PortalUser` (existing).
- Produces:
  - `public enum HTTPMethod: String, Sendable { case get = "GET"; case post = "POST"; case put = "PUT"; case delete = "DELETE"; case patch = "PATCH" }`
  - `public enum APIBase: Sendable { case portal; case metadata; case status }` with an internal `var pathPrefix: String` mapping `.portal → "api/v1/requests"`, `.metadata → "api/v1/metadata"`, `.status → "api/v1"`.
  - `public func send<T: Decodable>(_ path: String, method: HTTPMethod = .get, base: APIBase = .portal, token: String? = nil, body: Data? = nil) async throws -> T` on `PortalAPIClient`.
  - A private `perform(_ path: String, method: HTTPMethod, base: APIBase, token: String?, body: Data?) async throws -> Data`.

- [ ] **Step 1: Write the failing multi-base tests**

Add a `Probe` fixture and two tests **inside** the existing `@Suite(.serialized) struct PortalAPIClientTests { … }` in `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift` (place the `Probe` struct just below the `baseURL` property, and the tests after the existing `non2xxMapsToHttpErrorWithServerMessage` test):

```swift
    /// Minimal decodable fixture for exercising the request plumbing without a real model.
    private struct Probe: Decodable, Equatable { let ok: Bool }

    @Test func statusBaseTargetsPublicApiV1Path() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/v1/status")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{"ok":true}"#.utf8))
        }
        let probe: Probe = try await client().send("status", base: .status)
        #expect(probe == Probe(ok: true))
    }

    @Test func metadataBaseTargetsApiV1MetadataPathWithBearer() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/v1/metadata/movie/603")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{"ok":true}"#.utf8))
        }
        let probe: Probe = try await client().send("movie/603", base: .metadata, token: "tok")
        #expect(probe == Probe(ok: true))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'APIBase' in scope` (and the new `send(_:base:)` signature does not exist yet).

- [ ] **Step 3: Add the enums**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/HTTPMethod.swift`:

```swift
/// HTTP verbs used by `PortalAPIClient`. Raw values are the wire method names.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/APIBase.swift`:

```swift
/// The three API roots the client can target on the SlipStream HTTPS origin.
///
/// All three hang off the user's base URL; each contributes a different path prefix.
/// `portal` is the audience-scoped portal surface; `metadata` is the shared metadata
/// group (accepts the portal token); `status` is the public, unauthenticated status
/// endpoint. `metadata` and `status` live on `/api/v1`, outside the `/api/v1/requests`
/// portal base.
public enum APIBase: Sendable {
    case portal
    case metadata
    case status

    /// Path prefix appended to the base URL before the call's own path.
    var pathPrefix: String {
        switch self {
        case .portal: "api/v1/requests"
        case .metadata: "api/v1/metadata"
        case .status: "api/v1"
        }
    }
}
```

- [ ] **Step 4: Refactor `PortalAPIClient` to a `perform` core + public `send`**

Replace the entire contents of `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift` with:

```swift
import Foundation

/// `URLSession`-backed client for the SlipStream HTTP API.
///
/// Most calls target the portal surface under `/api/v1/requests`; the same client can also
/// reach the shared `/api/v1/metadata` group and the public `/api/v1/status` endpoint by
/// passing a different `APIBase`. Decode JSON responses with `send`; use `sendNoContent`
/// for endpoints that return `204 No Content`.
public final class PortalAPIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    private struct ServerErrorBody: Decodable {
        let message: String?
        let error: String?
    }

    /// Performs the request and returns the raw response body (empty `Data` for `204`).
    /// Maps transport failures, non-HTTP responses, and non-2xx statuses to `APIClientError`.
    private func perform(
        _ path: String,
        method: HTTPMethod,
        base: APIBase,
        token: String?,
        body: Data?
    ) async throws -> Data {
        let url = baseURL
            .appendingPathComponent(base.pathPrefix)
            .appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIClientError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.transport("Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(ServerErrorBody.self, from: data)
            throw APIClientError.http(
                status: http.statusCode,
                message: payload?.message,
                error: payload?.error
            )
        }
        return data
    }

    /// Sends a request and decodes a JSON body into `T`.
    /// Use `sendNoContent` for endpoints that return `204 No Content`.
    /// - Parameters:
    ///   - path: path relative to `base`, no leading slash (e.g. `"auth/login"`, `"movie/603"`, `"status"`).
    ///   - method: HTTP verb; defaults to `.get`.
    ///   - base: which API root to target; defaults to `.portal`.
    ///   - token: optional bearer token.
    ///   - body: optional pre-encoded request body.
    public func send<T: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        base: APIBase = .portal,
        token: String? = nil,
        body: Data? = nil
    ) async throws -> T {
        let data = try await perform(path, method: method, base: base, token: token, body: body)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIClientError.decoding(String(describing: error))
        }
    }
}

extension PortalAPIClient: AuthAPI {
    public func login(_ body: LoginRequest) async throws -> LoginResponse {
        let encoded = try JSONEncoder().encode(body)
        return try await send("auth/login", method: .post, base: .portal, token: nil, body: encoded)
    }

    public func profile(token: String) async throws -> PortalUser {
        try await send("auth/profile", method: .get, base: .portal, token: token)
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all pass. The two existing portal tests (`loginHitsCorrectPathAndDecodes`, `profileSendsBearerHeader`) and `non2xxMapsToHttpErrorWithServerMessage` are unaffected (they call `login`/`profile`, which still target `.portal`); the two new base tests pass. Suite total so far: 13 tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(kit): add HTTPMethod/APIBase and multi-base PortalAPIClient.send"
```

---

### Task 2: `204` / empty-body handling (`sendNoContent`)

Add a public no-decode variant for endpoints that return `204 No Content` (cancel request, unwatch, inbox mark-read / mark-all-read, notifications test). It funnels through the same `perform` core, so error mapping is identical; it simply ignores the (empty) body.

**Files:**
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift`

**Interfaces:**
- Consumes: the private `perform` (Task 1).
- Produces: `public func sendNoContent(_ path: String, method: HTTPMethod = .get, base: APIBase = .portal, token: String? = nil, body: Data? = nil) async throws` on `PortalAPIClient` — returns normally on any 2xx (including `204` with an empty body), throws `APIClientError` on non-2xx.

- [ ] **Step 1: Write the failing 204 tests**

Add these two tests inside `@Suite(.serialized) struct PortalAPIClientTests { … }`, after the Task 1 tests:

```swift
    @Test func sendNoContentSucceedsOn204() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url?.path == "/api/v1/requests/42")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
            let resp = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        // No throw == pass.
        try await client().sendNoContent("42", method: .delete, token: "tok")
    }

    @Test func sendNoContentMapsNon2xxToHttpError() async throws {
        StubURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{"error":"not found"}"#.utf8))
        }
        await #expect(throws: APIClientError.http(status: 404, message: nil, error: "not found")) {
            try await client().sendNoContent("999", method: .delete, token: "tok")
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `value of type 'PortalAPIClient' has no member 'sendNoContent'`.

- [ ] **Step 3: Add `sendNoContent`**

In `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift`, add this method to the `PortalAPIClient` class body, immediately after `send<T>`:

```swift
    /// Sends a request that returns no body (`204 No Content` / empty), e.g. cancel,
    /// unwatch, inbox mark-read, or a saved-channel test. Throws on any non-2xx status.
    public func sendNoContent(
        _ path: String,
        method: HTTPMethod = .get,
        base: APIBase = .portal,
        token: String? = nil,
        body: Data? = nil
    ) async throws {
        _ = try await perform(path, method: method, base: base, token: token, body: body)
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all pass. Suite total so far: 15 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add sendNoContent for 204/empty-body endpoints"
```

---

### Task 3: Central `401` hook (`onUnauthorized`)

Give the client an injected `@Sendable` closure that fires exactly once when a `401` comes back on a request that carried a token — the seam the F2.4 session-expiry handler will later consume to clear the session and re-prompt for the PIN. A `401` on a token-less request (e.g. a bad-PIN login) must **not** fire it, so sign-in failures stay local.

**Files:**
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift`

**Interfaces:**
- Consumes: the private `perform` (Task 1).
- Produces: a new initializer parameter
  `public init(baseURL: URL, session: URLSession = .shared, onUnauthorized: (@Sendable () -> Void)? = nil)`.
  Behavior: inside `perform`, when `http.statusCode == 401 && token != nil`, call `onUnauthorized?()` once before throwing the `APIClientError.http`. Non-401 errors and token-less 401s never call it. The default `nil` keeps every existing call site (`PortalAPIClient(baseURL:)`, `PortalAPIClient(baseURL:session:)`) source-compatible.

- [ ] **Step 1: Write the failing hook tests**

Add these three tests inside `@Suite(.serialized) struct PortalAPIClientTests { … }`, after the Task 2 tests. They build the client inline (not via the `client()` helper) so they can inject `onUnauthorized`, and use Swift Testing's `confirmation` to assert the fire count:

```swift
    @Test func tokenBearing401FiresUnauthorizedHookOnce() async throws {
        await confirmation("onUnauthorized fires once") { fired in
            let session = StubURLProtocol.makeSession()
            StubURLProtocol.handler = { request in
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (resp, Data(#"{"message":"expired"}"#.utf8))
            }
            let client = PortalAPIClient(baseURL: baseURL, session: session, onUnauthorized: { fired() })
            await #expect(throws: APIClientError.self) {
                let _: Probe = try await client.send("auth/profile", token: "expired-tok")
            }
        }
    }

    @Test func noToken401DoesNotFireHook() async throws {
        await confirmation("hook never fires", expectedCount: 0) { fired in
            let session = StubURLProtocol.makeSession()
            StubURLProtocol.handler = { request in
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (resp, Data(#"{"message":"bad creds"}"#.utf8))
            }
            let client = PortalAPIClient(baseURL: baseURL, session: session, onUnauthorized: { fired() })
            await #expect(throws: APIClientError.self) {
                _ = try await client.login(LoginRequest(username: "jack", password: "0000"))
            }
        }
    }

    @Test func non401ErrorDoesNotFireHook() async throws {
        await confirmation("hook never fires", expectedCount: 0) { fired in
            let session = StubURLProtocol.makeSession()
            StubURLProtocol.handler = { request in
                let resp = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (resp, Data(#"{"error":"boom"}"#.utf8))
            }
            let client = PortalAPIClient(baseURL: baseURL, session: session, onUnauthorized: { fired() })
            await #expect(throws: APIClientError.self) {
                let _: Probe = try await client.send("auth/profile", token: "tok")
            }
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `extra argument 'onUnauthorized' in call` (the initializer has no such parameter yet).

- [ ] **Step 3: Add the `onUnauthorized` seam**

In `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift`, replace the stored properties and initializer:

```swift
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
```

with:

```swift
    private let baseURL: URL
    private let session: URLSession
    private let onUnauthorized: (@Sendable () -> Void)?

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        onUnauthorized: (@Sendable () -> Void)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.onUnauthorized = onUnauthorized
    }
```

Then, in the same file, replace the non-2xx guard inside `perform`:

```swift
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(ServerErrorBody.self, from: data)
            throw APIClientError.http(
                status: http.statusCode,
                message: payload?.message,
                error: payload?.error
            )
        }
```

with (adds the token-bearing-401 fire before throwing):

```swift
        guard (200..<300).contains(http.statusCode) else {
            // Mirror the web client: signal unauthorized only when the request carried a
            // token, so a bad-PIN login 401 (no token) stays local to sign-in.
            if http.statusCode == 401, token != nil {
                onUnauthorized?()
            }
            let payload = try? JSONDecoder().decode(ServerErrorBody.self, from: data)
            throw APIClientError.http(
                status: http.statusCode,
                message: payload?.message,
                error: payload?.error
            )
        }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all pass — `tokenBearing401FiresUnauthorizedHookOnce` confirms exactly one fire; the two negative tests confirm zero. Suite total: 18 tests, 0 failures (`ModelDecodingTests` 2 + `PortalAPIClientTests` 10 + `AuthStoreTests` 6).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): emit central 401 hook on token-bearing unauthorized responses"
```

---

### Task 4: Finish the docs — mark F1.2 complete

The code scope is done; record it. Update the F1.2 spec status and resolve its open questions, then flip the tracker entry. (Docs-only task — no `/code-review` required for this commit per repo conventions, but the Task 1–3 code is reviewed in Task 5.)

**Files:**
- Modify: `docs/superpowers/specs/01-foundations/portal-api-client.md`
- Modify: `docs/TRACKER.md`

**Interfaces:**
- Consumes: nothing.
- Produces: updated status text only.

- [ ] **Step 1: Update the F1.2 spec status block and open questions**

In `docs/superpowers/specs/01-foundations/portal-api-client.md`, replace the status blockquote (the line beginning `> **Status (2026-06-20):** ◑ **Partial**`) with:

```markdown
> **Status (2026-06-20):** ✅ **Infrastructure complete** — Plan 1 (`d268544`) delivered the auth slice (`PortalAPIClient` + `APIClientError` + `AuthAPI`). The F1.2 finish plan ([`docs/superpowers/plans/2026-06-20-portal-api-client.md`](../../plans/2026-06-20-portal-api-client.md)) added the reusable plumbing: multi-base targeting via `APIBase` (`portal` / `metadata` / public `status`), a public `send`/`sendNoContent` request surface with `204`/empty handling, and a central `onUnauthorized` hook that fires on a token-bearing `401`. The per-resource endpoint methods (search/library/requests/inbox/notifications) are **not** part of F1.2 — they grow in their own feature plans (F3.x/F4.x/F6.x) on top of this client.
```

In the same file, update the **Open questions** section to resolve the retry question — replace:

```markdown
- [ ] Any retry/backoff policy for transient network errors, or fail fast?
```

with:

```markdown
- [x] ~~Any retry/backoff policy for transient network errors, or fail fast?~~ **Resolved: fail fast** — no retry/backoff, mirroring the web `portalFetch` (`web/src/api/portal/client.ts`). A transport error maps to `APIClientError.transport(_)` and surfaces immediately; polling features re-fetch on their own cadence.
```

- [ ] **Step 2: Update the tracker entry**

In `docs/TRACKER.md`, replace the F1.2 line:

```markdown
- [ ] ◑ **F1.2** [Portal API client](superpowers/specs/01-foundations/portal-api-client.md) — typed client, base path, Bearer JWT, error model, 401 hook · ◑ **Plan 1: auth subset done**
```

with:

```markdown
- [x] **F1.2** [Portal API client](superpowers/specs/01-foundations/portal-api-client.md) — typed client, base path, Bearer JWT, error model, 204/empty handling, multi-base (portal/metadata/status), central 401 hook · ✅ **infra done** (per-resource methods grow per feature)
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs: mark F1.2 portal API client infrastructure complete"
```

---

### Task 5: Verify and merge

Final gate. Confirm the whole suite is green, the app target still compiles against the changed client, run the mandated review, then squash-merge to `main`.

**Files:** none (verification + merge only).

- [ ] **Step 1: Run the full SlipStreamKit suite**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: `18 tests` pass, 0 failures.

- [ ] **Step 2: Confirm the app target still links**

The client's new `onUnauthorized` parameter defaults to `nil`, so `App/SlipStreamApp.swift` (`PortalAPIClient(baseURL: url)`) needs no change — this step only proves it. Build via XcodeBuildMCP:

```
mcp__xcodebuildmcp__build_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED`. (If `swift test` already passed and no app code changed, this is a fast linkage check.)

- [ ] **Step 3: Run the mandated code review**

Run the `/code-review` skill over the Task 1–3 diff (the non-docs changes). Triage findings with a bias toward acceptance, per `CLAUDE.md`. Apply any accepted fixes as follow-up commits and re-run `swift test`.

- [ ] **Step 4: Squash-merge to `main`**

Per `CLAUDE.md`, always squash-merge. If the work was done on a branch:

```bash
git checkout main
git merge --squash <work-branch>
git commit -m "feat(kit): finish F1.2 portal API client infrastructure (multi-base, 204, 401 hook)"
```

If committed directly on `main` (solo repo), this step is a no-op — confirm `git log --oneline -6` shows the four feature/docs commits and `swift test` is green on `main`.

---

## Self-Review

**1. Spec coverage** (against `portal-api-client.md` "In scope"):
- Base-path + URL construction; Bearer header injection → existing, preserved through `perform` (Task 1). ✓
- Success decode → `send<T>` (Task 1). ✓
- `204`/empty handling → `sendNoContent` (Task 2). ✓
- Typed error mapping (`{message?,error?}`) → existing `ServerErrorBody` path, preserved in `perform` (Task 1). ✓
- Central `401` hook → notify the auth layer → `onUnauthorized` seam, fires on token-bearing 401 (Task 3); the *consumer* wiring is F2.4 by design (noted in Global Constraints + File structure). ✓
- Multi-base (`/api/v1/metadata` + public `/api/v1/status`) → `APIBase` enum, proven by tests (Task 1). ✓
- Open question "retry/backoff?" → resolved fail-fast (Task 4 + Global Constraints). ✓
- Out of scope by decision: per-resource endpoint methods + their models (feature plans / F1.3) — explicitly excluded in Global Constraints. ✓

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N". Every code step shows complete code; every command states expected output. The only deferred work (F2.4 consuming the 401 hook; per-feature endpoint methods) is explicit scope exclusion, not a placeholder. ✓

**3. Type consistency:** `HTTPMethod` raw values (`GET`/`POST`/`DELETE`) match the `request.httpMethod` assertions in tests. `APIBase.pathPrefix` (`api/v1/requests` / `api/v1/metadata` / `api/v1`) matches the asserted URL paths (`/api/v1/requests/...`, `/api/v1/metadata/movie/603`, `/api/v1/status`). `send(_:method:base:token:body:)` and `sendNoContent(_:method:base:token:body:)` share an identical parameter list and both route through `perform(_:method:base:token:body:)`. `onUnauthorized: (@Sendable () -> Void)?` is identical in the interface block, the initializer, and the test call sites. `login`/`profile` use the new `send` signature with `.portal`/`.post`/`.get`. ✓

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-20-portal-api-client.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
