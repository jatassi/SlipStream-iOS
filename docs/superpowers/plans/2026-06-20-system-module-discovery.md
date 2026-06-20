# System & Module Discovery (F1.4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the app learn — from the public `GET /api/v1/status` — which media modules (movie / tv) are enabled and whether the portal is on, and combine that with the signed-in user's `moduleSettings` to compute exactly which modules *this* user may request, so later features can show/hide request flows and tabs instead of hardcoding movie+tv.

**Architecture:** Adds a small system-discovery slice to `SlipStreamKit`, mirroring the existing auth slice: a Codable `SystemStatus` model + a `ModuleType` enum, a `SystemAPI` protocol seam backed by the existing `PortalAPIClient` (calling the *public, no-token* `/api/v1/status`, which lives one path level above the `/api/v1/requests` portal base), and an `@MainActor @Observable SystemStore` that fetches status, exposes `portalEnabled` / `enabledModuleTypes`, and computes per-user requestable modules by intersecting server-enabled modules with the user's `moduleSettings`. All logic is unit-tested headlessly with `swift test` against the same `StubURLProtocol`/fakes the auth slice uses. A final task wires `SystemStore` into the app and surfaces the modules on the existing signed-in placeholder to verify the public `/status` call against a live server.

**Tech Stack:** Swift 6 (strict concurrency), `@Observable` (Observation), Swift Package Manager (local path packages), Swift Testing, `URLSession` async/await, SwiftUI (placeholder wiring only), XcodeBuildMCP for the simulator build/run.

## Global Constraints

- **Language/mode:** Swift 6, strict concurrency (`swift-tools-version: 6.0`). Every type crossing a concurrency boundary must be `Sendable`; UI/state types are `@MainActor`.
- **Deployment target:** iOS/iPadOS **26.0** minimum. `SlipStreamKit` also supports **macOS 14** so its pure-logic tests run via `swift test`.
- **Contract source of truth:** `~/Git/SlipStream`. Mirror field names verbatim (camelCase). Do not invent endpoints or fields. The relevant facts, already verified against the server:
  - `GET /api/v1/status` is **public — no token required** (registered before the protected group: `internal/api/routes.go:107-108`; handler `internal/api/handlers_system.go:27-69`). It returns, among other fields, `portalEnabled: bool` and `enabledModules: map[string]bool`. Web mirror: `web/src/types/system.ts` (`SystemStatus`).
  - `/status` lives on base **`/api/v1`**, *not* the `/api/v1/requests` portal base. It stays reachable even when `/api/v1/requests/*` returns `503` (that group is gated by `PortalEnabled()`), which is exactly why it is the discovery source for `portalEnabled`.
  - Module type strings are exactly **`{ "movie", "tv" }`** and stable (server: `internal/module/types.go:9-10` — `TypeMovie = "movie"`, `TypeTV = "tv"`). Model `ModuleType` as a `String` enum with these raw values. (This resolves the spec's last open question.)
  - Per-user allowed modules come from `PortalUser.moduleSettings` (already modeled in Plan 1), fetched via the portal-token-safe `GET /api/v1/requests/auth/profile` / returned inside `LoginResponse.user`.
- **Networking:** base URL is the user's **HTTPS** reverse-proxy origin, persisted by `ServerConfigStore`. `/status` is fetched with **no `Authorization` header**. Do not add an ATS arbitrary-loads exception.
- **No new dependencies.** Everything here is Foundation + the existing package surface. No `.xcodeproj` edits are needed: every new Swift file lives inside an existing SPM target (SwiftPM auto-discovers sources), and the app already links `SlipStreamKit`.
- **Commits:** frequent, one per task minimum. Squash-merge to `main`; run `/code-review` before merging (non-`docs/` changes).

---

## File structure (this plan)

```
SlipStream-iOS/
  Packages/SlipStreamKit/
    Sources/SlipStreamKit/
      Models/ModuleType.swift          # ModuleType enum {movie, tv}            (Task 1, new)
      Models/SystemStatus.swift        # SystemStatus model + derived accessors  (Task 1, new)
      Networking/SystemAPI.swift       # SystemAPI protocol seam                 (Task 2, new)
      Networking/PortalAPIClient.swift # add basePath param + SystemAPI conf.    (Task 2, modify)
      System/SystemStore.swift         # @MainActor @Observable SystemStore      (Task 3, new)
    Tests/SlipStreamKitTests/
      SystemStatusTests.swift          # model decoding + gating logic           (Task 1, new)
      PortalAPIClientTests.swift       # add status() path/no-token test         (Task 2, modify)
      Fakes.swift                      # add FakeSystemAPI + sampleStatus; ext.  (Task 3, modify)
      SystemStoreTests.swift           # store refresh + gating                   (Task 3, new)
  App/
    SlipStreamApp.swift                # compose + inject SystemStore             (Task 4, modify)
    SignedInPlaceholderView.swift      # surface modules; .task refresh           (Task 4, modify)
```

**Fast loop:** Tasks 1–3 are pure `SlipStreamKit` and run via `cd Packages/SlipStreamKit && swift test` (no simulator). Task 4 uses XcodeBuildMCP.

---

### Task 1: `ModuleType` + `SystemStatus` models

The Codable mirror of the portal-relevant subset of `/api/v1/status`, plus the `ModuleType` enum and the two derived accessors all later code reads: which known modules are enabled, and which of those a given user may request. Pure Foundation; tested headlessly with JSON fixtures.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/ModuleType.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/SystemStatus.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/SystemStatusTests.swift`

**Interfaces:**
- Consumes: `PortalUser`, `UserModuleSetting` (Plan 1).
- Produces:
  - `enum ModuleType: String, Codable, CaseIterable, Sendable { case movie; case tv }` — `allCases == [.movie, .tv]`.
  - `struct SystemStatus: Codable, Equatable, Sendable` with stored `portalEnabled: Bool`, `enabledModules: [String: Bool]?`, init `init(portalEnabled:enabledModules:)`, and:
    - `var enabledModuleTypes: [ModuleType]` — known modules marked enabled, in `ModuleType.allCases` order; falls back to `ModuleType.allCases` when `enabledModules == nil`.
    - `func requestableModules(for user: PortalUser) -> [ModuleType]` — `enabledModuleTypes` ∩ the user's `moduleSettings` module types.
    - `static let optimisticDefault: SystemStatus` — `portalEnabled: true, enabledModules: nil` (portal on, all modules enabled).

- [ ] **Step 1: Write the failing model tests**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/SystemStatusTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'ModuleType' in scope` / `cannot find 'SystemStatus' in scope`.

- [ ] **Step 3: Write the models**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/ModuleType.swift`:

```swift
import Foundation

/// The media modules the portal can expose. Raw values mirror the server's module
/// type strings (`internal/module/types.go`: `TypeMovie = "movie"`, `TypeTV = "tv"`).
public enum ModuleType: String, Codable, CaseIterable, Sendable {
    case movie
    case tv
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/SystemStatus.swift`:

```swift
import Foundation

/// Mirrors the portal-relevant subset of `GET /api/v1/status` (web/src/types/system.ts).
/// The endpoint is public (no token); unmodeled server fields are ignored on decode.
public struct SystemStatus: Codable, Equatable, Sendable {
    public let portalEnabled: Bool
    public let enabledModules: [String: Bool]?

    public init(portalEnabled: Bool, enabledModules: [String: Bool]?) {
        self.portalEnabled = portalEnabled
        self.enabledModules = enabledModules
    }

    /// Known module types the server reports as enabled, in canonical order
    /// (`ModuleType.allCases`). When the server omits the map entirely, fall back to
    /// all known modules so we never hide a feature on missing data.
    public var enabledModuleTypes: [ModuleType] {
        guard let enabledModules else { return ModuleType.allCases }
        return ModuleType.allCases.filter { enabledModules[$0.rawValue] == true }
    }

    /// Modules this user may request: server-enabled ∩ the user's allowed modules
    /// (`PortalUser.moduleSettings`). Unknown module strings on either side are ignored.
    public func requestableModules(for user: PortalUser) -> [ModuleType] {
        let allowed = Set(user.moduleSettings.compactMap { ModuleType(rawValue: $0.moduleType) })
        return enabledModuleTypes.filter { allowed.contains($0) }
    }

    /// Optimistic stand-in used before the first successful `/status` load:
    /// portal assumed enabled, all known modules assumed enabled.
    public static let optimisticDefault = SystemStatus(portalEnabled: true, enabledModules: nil)
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (the 9 new model tests plus the existing suite — no regressions).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add SystemStatus + ModuleType discovery models"
```

---

### Task 2: `SystemAPI` seam + public `/status` client call

Add the `SystemAPI` protocol and conform `PortalAPIClient` to it. Because `/status` is on base `/api/v1` (not `/api/v1/requests`) and takes no token, generalize `PortalAPIClient.send` with a `basePath` parameter (defaulting to the existing portal base, so the auth calls are unchanged). Tested with the existing `StubURLProtocol` — asserts the path is `/api/v1/status` and that **no** `Authorization` header is sent.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/SystemAPI.swift`
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift`

**Interfaces:**
- Consumes: `SystemStatus` (Task 1); `PortalAPIClient.send`, `APIClientError` (Plan 1).
- Produces:
  - `protocol SystemAPI: Sendable { func status() async throws -> SystemStatus }`
  - `PortalAPIClient` conforms to `SystemAPI`; `status()` issues `GET /api/v1/status` with `token: nil`.
  - `PortalAPIClient.send` gains `basePath: String = "api/v1/requests"` (default preserves all existing call sites).

- [ ] **Step 1: Write the failing client test**

Add this test inside the existing `@Suite(.serialized) struct PortalAPIClientTests` in `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift` (place it after `non2xxMapsToHttpErrorWithServerMessage`, before the closing brace):

```swift
    @Test func statusHitsPublicPathWithoutToken() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/v1/status")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let body = #"{"portalEnabled":true,"enabledModules":{"movie":true,"tv":true}}"#
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(body.utf8))
        }
        let status = try await client().status()
        #expect(status.portalEnabled == true)
        #expect(status.enabledModuleTypes == [.movie, .tv])
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `value of type 'PortalAPIClient' has no member 'status'`.

- [ ] **Step 3: Add the `basePath` parameter and `SystemAPI` conformance**

In `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift`, change the `send` signature and URL construction. Replace:

```swift
    /// `path` is relative to the portal base, no leading slash, e.g. "auth/login".
    func send<T: Decodable>(
        path: String,
        method: String,
        token: String?,
        body: Data?
    ) async throws -> T {
        let url = baseURL
            .appendingPathComponent("api/v1/requests")
            .appendingPathComponent(path)
```

with:

```swift
    /// `path` is relative to `basePath`, no leading slash, e.g. "auth/login".
    /// `basePath` defaults to the portal base; `/status` lives one level up at "api/v1".
    func send<T: Decodable>(
        path: String,
        method: String,
        token: String?,
        body: Data?,
        basePath: String = "api/v1/requests"
    ) async throws -> T {
        let url = baseURL
            .appendingPathComponent(basePath)
            .appendingPathComponent(path)
```

Then add a new conformance at the end of the file (after the existing `extension PortalAPIClient: AuthAPI { ... }`):

```swift
extension PortalAPIClient: SystemAPI {
    public func status() async throws -> SystemStatus {
        try await send(path: "status", method: "GET", token: nil, body: nil, basePath: "api/v1")
    }
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/SystemAPI.swift`:

```swift
/// The system-discovery surface SystemStore depends on. Backed by PortalAPIClient; faked in tests.
/// `status()` hits the public `GET /api/v1/status` (no token required).
public protocol SystemAPI: Sendable {
    func status() async throws -> SystemStatus
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass. The existing `loginHitsCorrectPathAndDecodes` / `profileSendsBearerHeader` tests still assert `/api/v1/requests/...` paths, confirming the `basePath` default left the portal calls unchanged.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add SystemAPI and public /status client call"
```

---

### Task 3: `SystemStore` with module-gating logic

The `@MainActor @Observable` state object that fetches `/status`, exposes `portalEnabled` / `enabledModuleTypes` with optimistic defaults before first load, records a non-fatal error on failure (keeping prior data), and computes per-user requestable modules. Depends only on the `SystemAPI` and `ServerConfigStore` seams, so it is fully unit-tested with fakes — no network, no simulator.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/System/SystemStore.swift`
- Modify: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/Fakes.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/SystemStoreTests.swift`

**Interfaces:**
- Consumes: `SystemAPI`, `SystemStatus`, `ModuleType`, `PortalUser`, `APIClientError`, `ServerConfigStore` (Tasks 1–2 + Plan 1).
- Produces:
  - `@MainActor @Observable final class SystemStore` with:
    - `init(makeSystemAPI: @escaping @Sendable (URL) -> SystemAPI, serverConfig: ServerConfigStore)`
    - `var status: SystemStatus?` (private set), `var lastError: APIClientError?` (private set)
    - `var effectiveStatus: SystemStatus` (loaded status or `.optimisticDefault`)
    - `var portalEnabled: Bool`, `var enabledModuleTypes: [ModuleType]`
    - `func requestableModules(for user: PortalUser) -> [ModuleType]`
    - `func refresh() async`
  - Test helpers in `Fakes.swift`: `struct FakeSystemAPI: SystemAPI`, `func sampleStatus(portalEnabled:enabledModules:)`, and a `moduleTypes:` parameter added to `sampleUser`.

- [ ] **Step 1: Add the system fakes and write the failing store tests**

Append to `Packages/SlipStreamKit/Tests/SlipStreamKitTests/Fakes.swift`:

```swift
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
```

In the same file, extend `sampleUser` to let tests give the user allowed modules. Replace:

```swift
func sampleUser(username: String = "jack") -> PortalUser {
    PortalUser(
        id: 1, username: username, moduleSettings: [],
        autoApprove: true, enabled: true, isAdmin: false,
        createdAt: "t", updatedAt: "t"
    )
}
```

with:

```swift
func sampleUser(username: String = "jack", moduleTypes: [String] = []) -> PortalUser {
    PortalUser(
        id: 1, username: username,
        moduleSettings: moduleTypes.map { UserModuleSetting(moduleType: $0, qualityProfileId: nil) },
        autoApprove: true, enabled: true, isAdmin: false,
        createdAt: "t", updatedAt: "t"
    )
}
```

(The added parameter defaults to `[]`, so the existing `sampleUser()` / `sampleUser(username:)` call sites in `AuthStoreTests` keep compiling unchanged.)

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/SystemStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@MainActor
@Suite struct SystemStoreTests {
    let serverURL = URL(string: "https://slipstream.example.com")!

    private func makeStore(
        api: FakeSystemAPI,
        config: FakeServerConfigStore
    ) -> SystemStore {
        SystemStore(makeSystemAPI: { _ in api }, serverConfig: config)
    }

    @Test func refreshSuccessStoresStatusAndModules() async {
        let api = FakeSystemAPI(onStatus: { sampleStatus(enabledModules: ["movie": true, "tv": false]) })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: serverURL))

        await store.refresh()

        #expect(store.status != nil)
        #expect(store.portalEnabled == true)
        #expect(store.enabledModuleTypes == [.movie])
        #expect(store.lastError == nil)
    }

    @Test func refreshWithNoServerURLKeepsOptimisticDefaults() async {
        let api = FakeSystemAPI(onStatus: {
            Issue.record("should not call /status without a configured server")
            return sampleStatus()
        })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: nil))

        await store.refresh()

        #expect(store.status == nil)
        #expect(store.portalEnabled == true)
        #expect(store.enabledModuleTypes == ModuleType.allCases)
        #expect(store.lastError == nil)
    }

    @Test func refreshFailureSetsErrorAndKeepsOptimisticDefaults() async {
        let api = FakeSystemAPI(onStatus: { throw APIClientError.http(status: 503, message: nil, error: nil) })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: serverURL))

        await store.refresh()

        #expect(store.lastError == .http(status: 503, message: nil, error: nil))
        #expect(store.status == nil)
        #expect(store.portalEnabled == true)              // optimistic default retained
        #expect(store.enabledModuleTypes == ModuleType.allCases)
    }

    @Test func portalDisabledPropagates() async {
        let api = FakeSystemAPI(onStatus: { sampleStatus(portalEnabled: false) })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: serverURL))

        await store.refresh()

        #expect(store.portalEnabled == false)
    }

    @Test func requestableModulesIntersectsUserWithServer() async {
        let api = FakeSystemAPI(onStatus: { sampleStatus(enabledModules: ["movie": true, "tv": false]) })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: serverURL))
        await store.refresh()

        let user = sampleUser(moduleTypes: ["movie", "tv"])
        #expect(store.requestableModules(for: user) == [.movie])   // tv disabled server-side
    }

    @Test func requestableModulesUsesOptimisticDefaultBeforeLoad() {
        let api = FakeSystemAPI(onStatus: { sampleStatus() })
        let store = makeStore(api: api, config: FakeServerConfigStore(url: serverURL))
        // No refresh() → status is nil → optimistic default (all modules enabled).

        let user = sampleUser(moduleTypes: ["tv"])
        #expect(store.requestableModules(for: user) == [.tv])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'SystemStore' in scope`.

- [ ] **Step 3: Write the `SystemStore`**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/System/SystemStore.swift`:

```swift
import Foundation
import Observation

/// Owns system/module discovery: fetches the public `GET /api/v1/status`, exposes
/// `portalEnabled` and the enabled module types, and computes which modules a given
/// user may request. Discovery is non-fatal — before the first successful load (or
/// after a failure) it serves optimistic defaults so the UI never hides a feature.
@MainActor
@Observable
public final class SystemStore {
    public private(set) var status: SystemStatus?
    public private(set) var lastError: APIClientError?

    private let makeSystemAPI: @Sendable (URL) -> SystemAPI
    private let serverConfig: ServerConfigStore

    public init(
        makeSystemAPI: @escaping @Sendable (URL) -> SystemAPI,
        serverConfig: ServerConfigStore
    ) {
        self.makeSystemAPI = makeSystemAPI
        self.serverConfig = serverConfig
    }

    /// The loaded status, or an optimistic stand-in (portal on, all modules enabled)
    /// before the first successful load.
    public var effectiveStatus: SystemStatus { status ?? .optimisticDefault }
    public var portalEnabled: Bool { effectiveStatus.portalEnabled }
    public var enabledModuleTypes: [ModuleType] { effectiveStatus.enabledModuleTypes }

    /// Modules this user may request: server-enabled ∩ the user's allowed modules.
    public func requestableModules(for user: PortalUser) -> [ModuleType] {
        effectiveStatus.requestableModules(for: user)
    }

    /// Fetch `/api/v1/status` (public, no token). On failure, keep the previous status
    /// and record the error rather than blanking discovery.
    public func refresh() async {
        guard let url = serverConfig.baseURL else { return }
        do {
            status = try await makeSystemAPI(url).status()
            lastError = nil
        } catch let error as APIClientError {
            lastError = error
        } catch {
            lastError = .transport(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (the 6 new store tests plus everything from Tasks 1–2 and Plan 1).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add SystemStore with module-gating logic"
```

---

### Task 4: Compose `SystemStore` and verify `/status` against a live server

Wire `SystemStore` into the app and surface the discovered modules on the existing signed-in placeholder. This empirically confirms the public `/status` call reaches the real server (the spec's key resolved assumption) and that the per-user gating reads correctly. The placeholder remains a temporary surface — the real tabs/gate consume `SystemStore` in later features (F1.6, F2.6).

**Files:**
- Modify: `App/SlipStreamApp.swift`
- Modify: `App/SignedInPlaceholderView.swift`

**Interfaces:**
- Consumes: `SystemStore`, `PortalAPIClient`, `UserDefaultsServerConfigStore`, `ModuleType` (SlipStreamKit); `AuthStore` (already injected).
- Produces: the running app showing enabled + requestable modules (no downstream consumers in this plan).

- [ ] **Step 1: Compose and inject `SystemStore` in the app entry point**

Replace `App/SlipStreamApp.swift` with:

```swift
import SwiftUI
import SlipStreamKit

@main
struct SlipStreamApp: App {
    @State private var auth = AuthStore(
        makeAuthAPI: { url in PortalAPIClient(baseURL: url) },
        tokenStore: KeychainTokenStore(),
        serverConfig: UserDefaultsServerConfigStore()
    )
    @State private var system = SystemStore(
        makeSystemAPI: { url in PortalAPIClient(baseURL: url) },
        serverConfig: UserDefaultsServerConfigStore()
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(system)
        }
    }
}
```

(The two `UserDefaultsServerConfigStore()` instances intentionally read the same persisted key — they are stateless views over `UserDefaults.standard`, so `AuthStore` and `SystemStore` always see the same server URL.)

- [ ] **Step 2: Surface enabled + requestable modules on the placeholder**

Replace `App/SignedInPlaceholderView.swift` with:

```swift
import SwiftUI
import SlipStreamKit

/// Placeholder proving auth + system discovery work end-to-end.
/// Replaced by the library browse UI / tabs in a later feature.
struct SignedInPlaceholderView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(SystemStore.self) private var system

    var body: some View {
        VStack(spacing: 16) {
            if case let .signedIn(user) = auth.state {
                Text("Signed in as \(user.username)").font(.headline)
                Text(user.autoApprove ? "Auto-approve: on" : "Auto-approve: off")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Enabled modules: \(moduleList(system.enabledModuleTypes))")
                    .font(.caption)
                Text("You can request: \(moduleList(system.requestableModules(for: user)))")
                    .font(.caption)
                if !system.portalEnabled {
                    Text("Portal is disabled on the server")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Button("Sign Out") {
                Task { await auth.signOut() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .task { await system.refresh() }
    }

    private func moduleList(_ modules: [ModuleType]) -> String {
        modules.isEmpty ? "none" : modules.map(\.rawValue).joined(separator: ", ")
    }
}
```

- [ ] **Step 3: Build and run on the simulator**

```
mcp__xcodebuildmcp__build_run_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED` and the app launches. (No `.xcodeproj` change was needed — the new `SystemStore` / model files live inside the already-linked `SlipStreamKit` package.)

- [ ] **Step 4: Manual end-to-end verification against a live instance**

Sign in with a real portal username + 4-digit PIN against the SlipStream HTTPS URL. Expected on the signed-in screen:
- "Enabled modules: movie, tv" (or whatever the server reports — confirms the **public `/status`** call succeeded with the configured server URL and no token).
- "You can request: …" lists only the modules in that user's `moduleSettings` that are also server-enabled.
- If the portal were disabled server-side, the orange "Portal is disabled on the server" line would appear (no need to toggle it for v1 — just confirm the wiring compiles and reads `portalEnabled`).

If anything misbehaves, capture logs:

```
mcp__xcodebuildmcp__start_sim_log_cap   (reproduce, then stop_sim_log_cap)
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(app): surface enabled/requestable modules from /status"
```

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/01-foundations/system-module-discovery.md`):
- "Discover enabled modules and gate movie-vs-tv request flows + library/search tabs accordingly" → `SystemStatus.enabledModuleTypes` + `SystemStore.enabledModuleTypes` (Tasks 1, 3); the consuming tabs/flows are later features that read these. ✓
- "Consume per-user `moduleSettings` (which modules this user can request)" → `SystemStatus.requestableModules(for:)` / `SystemStore.requestableModules(for:)` intersect server-enabled modules with the user's `moduleSettings` (Tasks 1, 3); surfaced live in Task 4. ✓
- "Surface `portalEnabled` to the portal-disabled gate" → `SystemStatus.portalEnabled` / `SystemStore.portalEnabled` (Tasks 1, 3); the F2.6 gate consumes `SystemStore.portalEnabled`. ✓
- Source of truth: public `GET /api/v1/status` on base `/api/v1` → Task 2 (`basePath: "api/v1"`, `token: nil`); path/no-token asserted in the client test. ✓
- "App-shell area polls `/status` at 30s" → `SystemStore.refresh()` is the unit of work; the 30s cadence is owned by the shared poller (F1.5) + app shell (F1.6). Task 4 drives a single `refresh()` via `.task` as interim wiring — deliberately *not* building a bespoke timer here that F1.5 would replace (YAGNI). ✓ (noted, not silently dropped)
- "Model module type as an enum with raw values `{ "movie", "tv" }`" → `ModuleType` (Task 1); raw values verified against `internal/module/types.go`, resolving the spec's open question. ✓

**2. Placeholder scan:** No "TBD" / "add error handling" / "similar to Task N". Every code step shows complete code; every command states expected output. The only deferred item (30s polling cadence) is explicitly assigned to F1.5/F1.6 with a rationale, not left vague.

**3. Type consistency:** Names match across tasks — `ModuleType` (`.movie`/`.tv`, `rawValue`, `allCases`); `SystemStatus.portalEnabled` / `.enabledModules` / `.enabledModuleTypes` / `.requestableModules(for:)` / `.optimisticDefault`; `SystemAPI.status()`; `PortalAPIClient.send(path:method:token:body:basePath:)` and its `SystemAPI` conformance; `SystemStore.init(makeSystemAPI:serverConfig:)` / `.status` / `.lastError` / `.effectiveStatus` / `.portalEnabled` / `.enabledModuleTypes` / `.requestableModules(for:)` / `.refresh()`. The `makeSystemAPI: @Sendable (URL) -> SystemAPI` signature is identical in the Task 3 interface block, the implementation, the tests, and the Task 4 composition. Test helpers (`FakeSystemAPI.onStatus`, `sampleStatus(portalEnabled:enabledModules:)`, `sampleUser(username:moduleTypes:)`) are referenced consistently. ✓

**Notes for the implementer:**
- Run Tasks 1–3 with `cd Packages/SlipStreamKit && swift test` (fast, no simulator). Task 4 uses XcodeBuildMCP.
- `PortalAPIClientTests` is `@Suite(.serialized)` because `StubURLProtocol.handler` is shared static state — keep the new `status` test inside that suite so it stays serialized.
- No `.xcodeproj` edits: SwiftPM auto-discovers the new files inside `SlipStreamKit`, and the app already links the package.
