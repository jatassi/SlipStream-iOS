# SlipStream-iOS Foundation (Plan 1) Implementation Plan

> ✅ **COMPLETE** — implemented and squash-merged to `main` in `d268544` (2026-06-20). `swift test` green (11/11 in `SlipStreamKit`). This plan is historical; live feature status is in [`docs/TRACKER.md`](../../TRACKER.md). The original 4-plan roadmap has been dropped — remaining features each get their own plan (one plan per spec).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the SlipStream-iOS app shell plus a tested `SlipStreamKit` networking/auth core and a `Feature-Auth` UI, so a user can sign in to a real SlipStream instance with username + 4-digit PIN, have the 30-day JWT stored in a Face-ID-gated Keychain, stay signed in across launches, and sign out.

**Architecture:** One Xcode app target (`SlipStream`, Designed-for-iPad so it runs on iPhone/iPad/Apple-Silicon Mac) composes local SPM packages. `SlipStreamKit` holds platform-agnostic Foundation code (Codable models mirroring the server's `portal.ts`, a `PortalAPIClient` over `URLSession`, a `TokenStore` seam with a real Keychain implementation, and an `@Observable` `AuthStore`) so its logic is unit-tested headlessly with `swift test` on the Mac host. `Feature-Auth` is an iOS-only SwiftUI package (sign-in + Face-ID gate) tested on the simulator via XcodeBuildMCP. Seams (`AuthAPI`, `TokenStore`, `ServerConfigStore`) are protocols so `AuthStore` is tested with in-memory fakes — no network, no Keychain, no simulator.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, `@Observable` (Observation), Swift Package Manager (local path packages), Swift Testing, `URLSession` async/await, Security + LocalAuthentication (Keychain + Face ID), XcodeBuildMCP for simulator build/test.

## Global Constraints

- **Language/mode:** Swift 6, strict concurrency (`swift-tools-version: 6.0`). Every type crossing a concurrency boundary must be `Sendable`; UI/state types are `@MainActor`.
- **Deployment target:** iOS/iPadOS **26.0** minimum. `SlipStreamKit` additionally supports **macOS 14** *only* so its pure-logic tests run via `swift test`; `Feature-Auth` is **iOS-only**.
- **Bundle id:** `dev.jatassi.slipstream`.
- **Signing:** free Apple Personal Team. No paid entitlements. No Associated Domains. Face ID via `NSFaceIDUsageDescription` only.
- **Networking:** base URL is the user's **HTTPS** reverse-proxy origin. Portal API base path is **`/api/v1/requests`**. Auth is `Authorization: Bearer <token>`. **Do not** add an ATS arbitrary-loads exception — the server is reached over real TLS.
- **Contract source of truth:** `~/Git/SlipStream/web/src/types/portal.ts` and `web/src/api/portal/`. Mirror field names verbatim (camelCase). Timestamp fields are typed `string` in the contract — model them as Swift `String` in v1 (no date parsing). Do not invent endpoints or fields.
- **Auth facts (from the server):** the login `password` field IS the 4-digit PIN (server enforces exactly 4 digits). JWT lives 30 days; **there is no refresh token**. On expiry, re-prompt for the PIN.
- **Keychain:** JWT only, never `UserDefaults`. Access control `.userPresence`, accessibility `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, evaluation policy `deviceOwnerAuthentication` (passcode fallback).
- **Commits:** frequent, one per task minimum. This repo is **not yet a git repo** — Task 1 initializes it.

---

## Plan sequence

This was **Plan 1 (foundation)** — scaffold + `SlipStreamKit` (models/API/auth) + `Feature-Auth`; delivered: sign in, persist the token behind Face ID, stay signed in, sign out.

The original Plans 2–4 roadmap has been **dropped** in favor of **one plan per spec** — each remaining feature gets its own plan at refinement. See [`docs/TRACKER.md`](../../TRACKER.md) and [`docs/superpowers/specs/`](../specs/README.md) for the live backlog and per-feature plan status.

---

## File structure (this plan)

```
SlipStream-iOS/
  .gitignore                              # Xcode + SPM ignores
  SlipStream.xcodeproj                    # generated once in Xcode (Task 1)
  App/
    SlipStreamApp.swift                   # @main; composes real dependencies (Task 7)
    RootView.swift                        # AuthGate → signed-in placeholder (Task 7)
    SignedInPlaceholderView.swift         # proves auth; replaced in Plan 2 (Task 7)
  Packages/
    SlipStreamKit/
      Package.swift                       # iOS 26 + macOS 14, library + test target (Task 1)
      Sources/SlipStreamKit/
        Models/PortalUser.swift           # PortalUser, UserModuleSetting (Task 2)
        Models/Auth.swift                 # LoginRequest, LoginResponse (Task 2)
        Networking/APIError.swift         # APIClientError (Task 3)
        Networking/AuthAPI.swift          # AuthAPI protocol (Task 3)
        Networking/PortalAPIClient.swift  # URLSession client + AuthAPI conformance (Task 3)
        Auth/TokenStore.swift             # TokenStore protocol (Task 4)
        Auth/ServerConfigStore.swift      # ServerConfigStore protocol + UserDefaults impl (Task 4)
        Auth/AuthStore.swift              # @MainActor @Observable AuthStore (Task 4)
        Auth/KeychainTokenStore.swift     # real biometric Keychain impl (Task 5)
      Tests/SlipStreamKitTests/
        ModelDecodingTests.swift          # (Task 2)
        StubURLProtocol.swift             # (Task 3)
        PortalAPIClientTests.swift        # (Task 3)
        Fakes.swift                       # FakeAuthAPI/TokenStore/ServerConfigStore (Task 4)
        AuthStoreTests.swift              # (Task 4)
    Feature-Auth/
      Package.swift                       # iOS 26 only; depends on ../SlipStreamKit (Task 6)
      Sources/FeatureAuth/
        AuthGateView.swift                # routes restore/signedOut/signedIn (Task 6)
        SignInView.swift                  # server URL + username + 4-digit PIN (Task 6)
  CLAUDE.md                               # from the setup doc §4.3 (Task 1)
  .mcp.json                               # XcodeBuildMCP, project scope (Task 1)
```

**External dependencies:** none added in this plan. Nuke arrives in Plan 2. No real-time/`/ws` dependency anywhere — Plan 4 uses polling against the same REST endpoints, so there is no server-side prerequisite.

---

### Task 1: Repo, packages, and the headless build loop

Scaffolding task. Deliverable: an empty-but-real app that **builds clean on the iPhone simulator** through XcodeBuildMCP, with both local packages linked and version-controlled. Project generation is the one manual Xcode step (per the setup doc); everything else is editable as plain files.

**Files:**
- Create: `.gitignore`, `.mcp.json`, `CLAUDE.md`
- Create: `Packages/SlipStreamKit/Package.swift`, `Packages/SlipStreamKit/Sources/SlipStreamKit/Empty.swift`
- Create (Xcode GUI): `SlipStream.xcodeproj`, `App/SlipStreamApp.swift` (default template, replaced in Task 7)

**Interfaces:**
- Consumes: nothing.
- Produces: a buildable `SlipStream` scheme; a `SlipStreamKit` SPM product linkable by the app and later packages.

- [ ] **Step 1: Initialize the git repo and ignore file**

Run from `/Users/jatassi/Git/SlipStream-iOS` (skip `git init` if already initialized):

```bash
git init
```

Create `.gitignore`:

```gitignore
# Xcode
build/
DerivedData/
*.xcuserstate
xcuserdata/
*.xcscmblueprint
*.xccheckout

# SPM
.build/
.swiftpm/

# macOS
.DS_Store
```

- [ ] **Step 2: Create the SlipStreamKit package**

Create `Packages/SlipStreamKit/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SlipStreamKit",
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "SlipStreamKit", targets: ["SlipStreamKit"]),
    ],
    targets: [
        .target(name: "SlipStreamKit"),
        .testTarget(name: "SlipStreamKitTests", dependencies: ["SlipStreamKit"]),
    ]
)
```

Create a placeholder so the target compiles — `Packages/SlipStreamKit/Sources/SlipStreamKit/Empty.swift`:

```swift
// Intentionally empty; real types arrive in Task 2+.
```

- [ ] **Step 3: Verify the package builds headlessly**

Run:

```bash
cd Packages/SlipStreamKit && swift build
```

Expected: `Build complete!` (no errors). This is the fast loop you'll use for Tasks 2–5.

- [ ] **Step 4: Generate the app project in Xcode (manual)**

In Xcode 26: File → New → Project → iOS → App. Product name `SlipStream`, bundle id `dev.jatassi.slipstream`, interface SwiftUI, language Swift, **iOS 26.0** deployment target, supported devices **iPhone + iPad**. Save into `/Users/jatassi/Git/SlipStream-iOS` so the project sits at `SlipStream.xcodeproj` with sources under `App/` (move the generated `ContentView.swift`/app file into `App/` if Xcode places them elsewhere).

Then:
- Target → General → **Supported Destinations** → add **Mac (Designed for iPad)**.
- Target → Build Settings → add `INFOPLIST_KEY_NSFaceIDUsageDescription` = `Unlock SlipStream with Face ID`.
- File → Add Package Dependencies → **Add Local…** → select `Packages/SlipStreamKit` → add the `SlipStreamKit` library to the `SlipStream` target.

- [ ] **Step 5: Add project-scoped XcodeBuildMCP config and CLAUDE.md**

Create `.mcp.json`:

```json
{
  "mcpServers": {
    "xcodebuildmcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest", "mcp"],
      "env": {
        "XCODEBUILDMCP_ENABLED_WORKFLOWS": "simulator,project-discovery,ui-automation,debugging"
      }
    }
  }
}
```

Create `CLAUDE.md` using the block from `docs/slipstream-ios-setup.md` §4.3 (scheme `SlipStream`; tools `build_sim`/`test_sim`/`start_sim_log_cap`; contract source `web/src/types/portal.ts`). Restart Claude Code so the MCP and the token-wrapping skill load.

- [ ] **Step 6: Verify the app builds on the simulator via XcodeBuildMCP**

Use the MCP build tool (token-wrapped):

```
mcp__xcodebuildmcp__build_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED` (one-line summary + xcresult id). If the simulator name is unknown, run `xcrun simctl list devices` and pick an installed one, then set it in `.xcodebuildmcp/config.yaml` `sessionDefaults`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: scaffold app, SlipStreamKit package, and XcodeBuildMCP loop"
```

---

### Task 2: Portal models (Codable mirrors)

The minimal model subset auth needs, mirrored verbatim from `portal.ts`. Pure Foundation, tested headlessly with JSON fixtures.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/PortalUser.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Auth.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/ModelDecodingTests.swift`
- Delete: `Packages/SlipStreamKit/Sources/SlipStreamKit/Empty.swift` (now superfluous)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `PortalUser(id:username:moduleSettings:autoApprove:enabled:isAdmin:createdAt:updatedAt:)` — `Codable, Equatable, Sendable, Identifiable`.
  - `UserModuleSetting(moduleType:qualityProfileId:)` — `qualityProfileId: Int?`.
  - `LoginRequest(username:password:)`, `LoginResponse{ token: String, user: PortalUser, isAdmin: Bool }` — `Codable, Equatable, Sendable`.

- [ ] **Step 1: Write the failing decoding test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/ModelDecodingTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct ModelDecodingTests {
    @Test func decodesLoginResponseWithNestedUser() throws {
        let json = """
        {
          "token": "jwt.abc.def",
          "isAdmin": false,
          "user": {
            "id": 7,
            "username": "jack",
            "moduleSettings": [
              { "moduleType": "movie", "qualityProfileId": 3 },
              { "moduleType": "tv", "qualityProfileId": null }
            ],
            "autoApprove": true,
            "enabled": true,
            "isAdmin": false,
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-02T00:00:00Z"
          }
        }
        """
        let data = Data(json.utf8)
        let resp = try JSONDecoder().decode(LoginResponse.self, from: data)

        #expect(resp.token == "jwt.abc.def")
        #expect(resp.isAdmin == false)
        #expect(resp.user.id == 7)
        #expect(resp.user.username == "jack")
        #expect(resp.user.moduleSettings.count == 2)
        #expect(resp.user.moduleSettings[0].qualityProfileId == 3)
        #expect(resp.user.moduleSettings[1].qualityProfileId == nil)
        #expect(resp.user.autoApprove == true)
    }

    @Test func encodesLoginRequestWithPasswordField() throws {
        let body = LoginRequest(username: "jack", password: "1234")
        let data = try JSONEncoder().encode(body)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(obj?["username"] == "jack")
        #expect(obj?["password"] == "1234")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'LoginResponse' in scope`.

- [ ] **Step 3: Write the models**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/PortalUser.swift`:

```swift
import Foundation

/// Mirrors `UserModuleSetting` in web/src/types/portal.ts.
public struct UserModuleSetting: Codable, Equatable, Sendable {
    public let moduleType: String
    public let qualityProfileId: Int?

    public init(moduleType: String, qualityProfileId: Int?) {
        self.moduleType = moduleType
        self.qualityProfileId = qualityProfileId
    }
}

/// Mirrors `PortalUser` in web/src/types/portal.ts.
public struct PortalUser: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let username: String
    public let moduleSettings: [UserModuleSetting]
    public let autoApprove: Bool
    public let enabled: Bool
    public let isAdmin: Bool
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: Int,
        username: String,
        moduleSettings: [UserModuleSetting],
        autoApprove: Bool,
        enabled: Bool,
        isAdmin: Bool,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.username = username
        self.moduleSettings = moduleSettings
        self.autoApprove = autoApprove
        self.enabled = enabled
        self.isAdmin = isAdmin
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Auth.swift`:

```swift
import Foundation

/// Mirrors `LoginRequest` in web/src/types/portal.ts. The `password` field carries the 4-digit PIN.
public struct LoginRequest: Codable, Equatable, Sendable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// Mirrors `LoginResponse` in web/src/types/portal.ts.
public struct LoginResponse: Codable, Equatable, Sendable {
    public let token: String
    public let user: PortalUser
    public let isAdmin: Bool

    public init(token: String, user: PortalUser, isAdmin: Bool) {
        self.token = token
        self.user = user
        self.isAdmin = isAdmin
    }
}
```

Delete the placeholder:

```bash
rm Packages/SlipStreamKit/Sources/SlipStreamKit/Empty.swift
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (2 tests, no failures).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add PortalUser and auth models mirroring portal.ts"
```

---

### Task 3: PortalAPIClient + error model

The `URLSession` client that hits `/api/v1/requests/*` with `Bearer` auth, decodes success, and maps non-2xx to a typed error (reading the server's `{message?, error?}` body, mirroring `client.ts`). Tested with a `URLProtocol` stub — no network.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/APIError.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/AuthAPI.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/StubURLProtocol.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift`

**Interfaces:**
- Consumes: `LoginRequest`, `LoginResponse`, `PortalUser` (Task 2).
- Produces:
  - `enum APIClientError: Error, Equatable, Sendable { case http(status: Int, message: String?, error: String?); case decoding(String); case transport(String) }`
  - `protocol AuthAPI: Sendable { func login(_ body: LoginRequest) async throws -> LoginResponse; func profile(token: String) async throws -> PortalUser }`
  - `final class PortalAPIClient: Sendable, AuthAPI` with `init(baseURL: URL, session: URLSession = .shared)`. Builds URLs as `baseURL + "api/v1/requests" + path`.

- [ ] **Step 1: Write the failing client tests**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/StubURLProtocol.swift`:

```swift
import Foundation

/// Intercepts URLSession requests in tests so no real network is used.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
```

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct PortalAPIClientTests {
    let baseURL = URL(string: "https://slipstream.example.com")!

    private func client() -> PortalAPIClient {
        PortalAPIClient(baseURL: baseURL, session: StubURLProtocol.makeSession())
    }

    @Test func loginHitsCorrectPathAndDecodes() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/v1/requests/auth/login")
            #expect(request.httpMethod == "POST")
            let body = """
            {"token":"tok","isAdmin":false,
             "user":{"id":1,"username":"jack","moduleSettings":[],
                     "autoApprove":true,"enabled":true,"isAdmin":false,
                     "createdAt":"t","updatedAt":"t"}}
            """
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(body.utf8))
        }
        let resp = try await client().login(LoginRequest(username: "jack", password: "1234"))
        #expect(resp.token == "tok")
        #expect(resp.user.username == "jack")
    }

    @Test func profileSendsBearerHeader() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/v1/requests/auth/profile")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
            let body = """
            {"id":1,"username":"jack","moduleSettings":[],
             "autoApprove":true,"enabled":true,"isAdmin":false,
             "createdAt":"t","updatedAt":"t"}
            """
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(body.utf8))
        }
        let user = try await client().profile(token: "tok")
        #expect(user.username == "jack")
    }

    @Test func non2xxMapsToHttpErrorWithServerMessage() async throws {
        StubURLProtocol.handler = { request in
            let body = #"{"message":"invalid credentials"}"#
            let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data(body.utf8))
        }
        await #expect(throws: APIClientError.http(status: 401, message: "invalid credentials", error: nil)) {
            _ = try await client().login(LoginRequest(username: "jack", password: "0000"))
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'PortalAPIClient' in scope`.

- [ ] **Step 3: Write the error type, protocol, and client**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/APIError.swift`:

```swift
import Foundation

/// Typed failures from PortalAPIClient. Mirrors the web client's ApiError(status, {message?, error?}).
public enum APIClientError: Error, Equatable, Sendable {
    case http(status: Int, message: String?, error: String?)
    case decoding(String)
    case transport(String)
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/AuthAPI.swift`:

```swift
/// The auth surface AuthStore depends on. Backed by PortalAPIClient; faked in tests.
public protocol AuthAPI: Sendable {
    func login(_ body: LoginRequest) async throws -> LoginResponse
    func profile(token: String) async throws -> PortalUser
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift`:

```swift
import Foundation

/// URLSession-backed client for the portal surface under `/api/v1/requests`.
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
        var request = URLRequest(url: url)
        request.httpMethod = method
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
        return try await send(path: "auth/login", method: "POST", token: nil, body: encoded)
    }

    public func profile(token: String) async throws -> PortalUser {
        try await send(path: "auth/profile", method: "GET", token: token, body: nil)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (5 total now).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add PortalAPIClient with typed errors and AuthAPI"
```

---

### Task 4: AuthStore + seams (TokenStore, ServerConfigStore)

The `@MainActor @Observable` state object that owns sign-in/restore/sign-out, depending only on protocol seams so it's fully unit-tested with fakes. No Keychain, no network, no simulator.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/TokenStore.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/ServerConfigStore.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/AuthStore.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/Fakes.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/AuthStoreTests.swift`

**Interfaces:**
- Consumes: `AuthAPI`, `LoginRequest`, `LoginResponse`, `PortalUser`, `APIClientError` (Tasks 2–3).
- Produces:
  - `protocol TokenStore: Sendable { func save(_ token: String) throws; func load() async throws -> String?; func delete() throws }`
  - `protocol ServerConfigStore: Sendable { var baseURL: URL? { get }; func setBaseURL(_ url: URL) }` + `final class UserDefaultsServerConfigStore`.
  - `@MainActor @Observable final class AuthStore` with:
    - `enum State: Equatable { case signedOut; case signedIn(PortalUser) }`
    - `init(makeAuthAPI: @escaping @Sendable (URL) -> AuthAPI, tokenStore: TokenStore, serverConfig: ServerConfigStore)`
    - `var state`, `var lastError: AuthError?`, `var hasAttemptedRestore: Bool`, `var currentToken: String?`, `var serverBaseURLString: String?`
    - `func restore() async`, `func signIn(serverURL: URL, username: String, pin: String) async`, `func signOut() async`
  - `enum AuthError: Error, Equatable, Sendable { case invalidPIN; case badCredentials; case server(status: Int); case network(String) }`

- [ ] **Step 1: Write the failing AuthStore tests**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/Fakes.swift`:

```swift
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
```

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/AuthStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@MainActor
@Suite struct AuthStoreTests {
    let serverURL = URL(string: "https://slipstream.example.com")!

    private func makeStore(
        api: FakeAuthAPI,
        tokenStore: FakeTokenStore = FakeTokenStore(),
        config: FakeServerConfigStore = FakeServerConfigStore()
    ) -> AuthStore {
        AuthStore(
            makeAuthAPI: { _ in api },
            tokenStore: tokenStore,
            serverConfig: config
        )
    }

    @Test func signInRejectsNonFourDigitPIN() async {
        let api = FakeAuthAPI(
            onLogin: { _ in Issue.record("should not call login"); throw APIClientError.transport("x") },
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
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'AuthStore' in scope`.

- [ ] **Step 3: Write the seams and AuthStore**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/TokenStore.swift`:

```swift
/// Storage seam for the JWT. `load()` is async because the real implementation prompts for Face ID.
public protocol TokenStore: Sendable {
    func save(_ token: String) throws
    func load() async throws -> String?
    func delete() throws
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/ServerConfigStore.swift`:

```swift
import Foundation

/// Non-secret persistence of the server's base URL (the HTTPS reverse-proxy origin).
public protocol ServerConfigStore: Sendable {
    var baseURL: URL? { get }
    func setBaseURL(_ url: URL)
}

public final class UserDefaultsServerConfigStore: ServerConfigStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "slipstream.serverBaseURL"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var baseURL: URL? {
        defaults.string(forKey: key).flatMap(URL.init(string:))
    }

    public func setBaseURL(_ url: URL) {
        defaults.set(url.absoluteString, forKey: key)
    }
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/AuthStore.swift`:

```swift
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
    private var token: String?

    public init(
        makeAuthAPI: @escaping @Sendable (URL) -> AuthAPI,
        tokenStore: TokenStore,
        serverConfig: ServerConfigStore
    ) {
        self.makeAuthAPI = makeAuthAPI
        self.tokenStore = tokenStore
        self.serverConfig = serverConfig
    }

    public var currentToken: String? { token }
    public var serverBaseURLString: String? { serverConfig.baseURL?.absoluteString }

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

    public func signOut() async {
        try? tokenStore.delete()
        token = nil
        state = .signedOut
    }

    private func isValidPIN(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (11 total).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add AuthStore with TokenStore/ServerConfigStore seams"
```

---

### Task 5: KeychainTokenStore (real biometric implementation)

The production `TokenStore` backed by the Keychain with a biometric access-control flag. It can't be meaningfully unit-tested (needs Secure Enclave / a real device or simulator), so this task's gate is "compiles for iOS and macOS, and a simulator smoke test stores+reads a token across a relaunch."

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/KeychainTokenStore.swift`

**Interfaces:**
- Consumes: `TokenStore` (Task 4).
- Produces:
  - `struct KeychainTokenStore: TokenStore` with `init(service: String = "dev.jatassi.slipstream.portal-jwt", account: String = "portal-token")`.
  - `enum KeychainError: Error, Equatable { case accessControl; case userCanceled; case unhandled(OSStatus) }`

- [ ] **Step 1: Write the implementation**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/KeychainTokenStore.swift`:

```swift
import Foundation
import Security
import LocalAuthentication

public enum KeychainError: Error, Equatable {
    case accessControl
    case userCanceled
    case unhandled(OSStatus)
}

/// Stores the JWT in the Keychain behind `.userPresence` (Face ID / Touch ID / passcode),
/// accessible only when the device is unlocked, and never synced off-device.
public struct KeychainTokenStore: TokenStore {
    private let service: String
    private let account: String

    public init(
        service: String = "dev.jatassi.slipstream.portal-jwt",
        account: String = "portal-token"
    ) {
        self.service = service
        self.account = account
    }

    public func save(_ token: String) throws {
        // Replace any existing item.
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)

        var acError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &acError
        ) else {
            throw KeychainError.accessControl
        }

        let status = SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessControl as String: access,
        ] as CFDictionary, nil)

        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    public func load() async throws -> String? {
        // The biometric prompt is presented by the system; run the (blocking) Keychain read
        // off the main actor so the UI stays responsive.
        let service = self.service
        let account = self.account
        return try await Task.detached(priority: .userInitiated) {
            let context = LAContext()
            context.localizedReason = "Unlock SlipStream"

            var item: CFTypeRef?
            let status = SecItemCopyMatching([
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseAuthenticationContext as String: context,
            ] as CFDictionary, &item)

            switch status {
            case errSecSuccess:
                guard let data = item as? Data else { return nil }
                return String(data: data, encoding: .utf8)
            case errSecItemNotFound:
                return nil
            case errSecUserCanceled:
                throw KeychainError.userCanceled
            default:
                throw KeychainError.unhandled(status)
            }
        }.value
    }

    public func delete() throws {
        let status = SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles on both platforms**

Run: `cd Packages/SlipStreamKit && swift build && swift test`
Expected: `Build complete!` and all existing tests still pass (the Keychain type is compiled but not exercised by `swift test`).

- [ ] **Step 3: Simulator smoke test (deferred verification, documented here)**

This implementation is verified end-to-end in Task 7's run, where signing in writes a token and relaunching reads it back behind Face ID. (On the simulator, enable Features → Face ID → Enrolled, and use Features → Face ID → Matching Face to satisfy the prompt.) No standalone test target step here — `.userPresence` items can't be exercised by `swift test`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(kit): add biometric KeychainTokenStore"
```

---

### Task 6: Feature-Auth UI package

The iOS-only SwiftUI package: a sign-in form (server URL + username + 4-digit PIN) and a gate view that shows a spinner during restore, the form when signed out, and the caller's content when signed in. Verified by building on the simulator.

**Files:**
- Create: `Packages/Feature-Auth/Package.swift`
- Create: `Packages/Feature-Auth/Sources/FeatureAuth/AuthGateView.swift`
- Create: `Packages/Feature-Auth/Sources/FeatureAuth/SignInView.swift`

**Interfaces:**
- Consumes: `AuthStore`, `AuthError` (Task 4), injected via SwiftUI `@Environment(AuthStore.self)`.
- Produces:
  - `struct AuthGateView<SignedIn: View>: View` with `init(@ViewBuilder signedIn: @escaping () -> SignedIn)`.
  - `struct SignInView: View` with `init()`.

- [ ] **Step 1: Create the package manifest**

Create `Packages/Feature-Auth/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureAuth",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "FeatureAuth", targets: ["FeatureAuth"]),
    ],
    dependencies: [
        .package(path: "../SlipStreamKit"),
    ],
    targets: [
        .target(
            name: "FeatureAuth",
            dependencies: ["SlipStreamKit"]
        ),
    ]
)
```

- [ ] **Step 2: Write the sign-in form**

Create `Packages/Feature-Auth/Sources/FeatureAuth/SignInView.swift`:

```swift
import SwiftUI
import SlipStreamKit

public struct SignInView: View {
    @Environment(AuthStore.self) private var auth
    @State private var serverURLString = ""
    @State private var username = ""
    @State private var pin = ""
    @State private var isSubmitting = false

    public init() {}

    public var body: some View {
        Form {
            Section("Server") {
                TextField("https://slipstream.example.com", text: $serverURLString)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Section("Sign In") {
                TextField("Username", text: $username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("4-digit PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .onChange(of: pin) { _, newValue in
                        pin = String(newValue.prefix(4).filter(\.isNumber))
                    }
            }
            if let error = auth.lastError {
                Section {
                    Text(message(for: error)).foregroundStyle(.red)
                }
            }
            Section {
                Button(action: submit) {
                    if isSubmitting { ProgressView() } else { Text("Sign In") }
                }
                .disabled(!canSubmit || isSubmitting)
            }
        }
        .onAppear {
            if serverURLString.isEmpty, let existing = auth.serverBaseURLString {
                serverURLString = existing
            }
        }
    }

    private var canSubmit: Bool {
        guard let url = URL(string: serverURLString), url.scheme?.hasPrefix("http") == true else {
            return false
        }
        return !username.isEmpty && pin.count == 4
    }

    private func submit() {
        guard let url = URL(string: serverURLString) else { return }
        isSubmitting = true
        Task {
            await auth.signIn(serverURL: url, username: username, pin: pin)
            isSubmitting = false
        }
    }

    private func message(for error: AuthError) -> String {
        switch error {
        case .invalidPIN: "PIN must be exactly 4 digits."
        case .badCredentials: "Incorrect username or PIN."
        case .server(let status): "Server error (\(status)). Please try again."
        case .network(let detail): "Network error: \(detail)"
        }
    }
}
```

- [ ] **Step 3: Write the gate view**

Create `Packages/Feature-Auth/Sources/FeatureAuth/AuthGateView.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// Drives the top-level auth flow: a spinner until restore finishes, then either
/// the sign-in form (signed out) or the caller's signed-in content.
public struct AuthGateView<SignedIn: View>: View {
    @Environment(AuthStore.self) private var auth
    private let signedIn: () -> SignedIn

    public init(@ViewBuilder signedIn: @escaping () -> SignedIn) {
        self.signedIn = signedIn
    }

    public var body: some View {
        Group {
            if !auth.hasAttemptedRestore {
                ProgressView("Unlocking…")
            } else {
                switch auth.state {
                case .signedIn:
                    signedIn()
                case .signedOut:
                    SignInView()
                }
            }
        }
        .task { await auth.restore() }
    }
}
```

- [ ] **Step 4: Link Feature-Auth into the app and build on the simulator**

In Xcode: File → Add Package Dependencies → Add Local… → `Packages/Feature-Auth` → add `FeatureAuth` to the `SlipStream` target.

Then build:

```
mcp__xcodebuildmcp__build_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED`. (The views aren't shown until Task 7 wires them in.)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(auth): add SignInView and AuthGateView"
```

---

### Task 7: App composition + end-to-end run

Wire the real dependencies into the app, route through the gate, and verify the full loop against a live SlipStream instance on the simulator.

**Files:**
- Modify: `App/SlipStreamApp.swift`
- Create: `App/RootView.swift`
- Create: `App/SignedInPlaceholderView.swift`

**Interfaces:**
- Consumes: `AuthStore`, `PortalAPIClient`, `KeychainTokenStore`, `UserDefaultsServerConfigStore` (SlipStreamKit); `AuthGateView` (FeatureAuth).
- Produces: the running app (no downstream consumers in this plan).

- [ ] **Step 1: Compose dependencies in the app entry point**

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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
    }
}
```

- [ ] **Step 2: Add the root view and signed-in placeholder**

Create `App/RootView.swift`:

```swift
import SwiftUI
import FeatureAuth

struct RootView: View {
    var body: some View {
        AuthGateView {
            SignedInPlaceholderView()
        }
    }
}
```

Create `App/SignedInPlaceholderView.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// Placeholder proving auth works end-to-end. Replaced by the library browse UI in Plan 2.
struct SignedInPlaceholderView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        VStack(spacing: 16) {
            if case let .signedIn(user) = auth.state {
                Text("Signed in as \(user.username)").font(.headline)
                Text(user.autoApprove ? "Auto-approve: on" : "Auto-approve: off")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Sign Out") {
                Task { await auth.signOut() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

- [ ] **Step 3: Build and launch on the simulator**

```
mcp__xcodebuildmcp__build_run_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED` and the app launches showing the sign-in form (after a brief "Unlocking…").

- [ ] **Step 4: Manual end-to-end verification against a live instance**

In the simulator: set Features → Face ID → Enrolled. Enter your SlipStream HTTPS URL, a real portal username, and its 4-digit PIN; tap Sign In. Expected: the screen shows "Signed in as <username>". Then:
- Background and relaunch the app. Expected: "Unlocking…", a Face ID prompt (Features → Face ID → Matching Face), then straight to the signed-in screen — no PIN re-entry.
- Tap Sign Out, relaunch. Expected: back to the sign-in form.

Capture logs if anything misbehaves:

```
mcp__xcodebuildmcp__start_sim_log_cap   (then reproduce, then stop_sim_log_cap)
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(app): compose AuthStore and route through AuthGateView"
```

---

## Self-Review

**1. Spec coverage** (against the locked decisions and setup doc §6):
- Username + 4-digit PIN sign-in → Tasks 2 (`LoginRequest`), 3 (`login`), 4 (`signIn` + PIN validation), 6 (form). ✓
- 30-day JWT, no refresh; re-prompt on expiry → Task 4 `restore()` 401 path deletes token and signs out. ✓
- Token in Face-ID-gated Keychain (`.userPresence`, `WhenUnlockedThisDeviceOnly`, `deviceOwnerAuthentication`) → Task 5. ✓
- Stays signed in across launches → Task 4 `restore()` + Task 6 gate `.task`; verified Task 7 Step 4. ✓
- HTTPS base URL, `/api/v1/requests`, Bearer; no ATS exception → Task 3 + Global Constraints; Task 1 sets only `NSFaceIDUsageDescription`. ✓
- Designed-for-iPad (iPhone/iPad/Mac) → Task 1 Step 4. ✓
- Quota/push/passkeys cut; real-time is polling (Plan 4), no WebSocket, no server change → none of those surfaces appear in this plan; roadmap item 4 is polling-only. ✓
- Contract mirrored from `portal.ts` verbatim, timestamps as `String` → Tasks 2–3. ✓

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N". Every code step shows complete code; every command has expected output. The only intentionally-deferred verification (Task 5 biometric path) is explicitly justified and exercised in Task 7. ✓

**3. Type consistency:** Names match across tasks — `AuthAPI.login/profile`, `PortalAPIClient.send`, `TokenStore.save/load/delete`, `ServerConfigStore.baseURL/setBaseURL`, `AuthStore.state/lastError/hasAttemptedRestore/currentToken/serverBaseURLString/restore/signIn/signOut`, `AuthError` cases, `AuthGateView(signedIn:)`. The `makeAuthAPI: @Sendable (URL) -> AuthAPI` signature is identical in the Task 4 interface block, the implementation, the tests, and the Task 7 composition. ✓

**Notes for the implementer:**
- Run Tasks 2–5 with `swift test` in `Packages/SlipStreamKit` (fast, no simulator). Tasks 1, 6, 7 use XcodeBuildMCP.
- If `swift test` can't resolve the macOS platform, confirm Xcode 26 is selected (`xcode-select -p`) so `swift` is the Swift 6 toolchain.
- The `nonisolated(unsafe) static var handler` in `StubURLProtocol` is test-only and safe because tests set it before each request synchronously.
