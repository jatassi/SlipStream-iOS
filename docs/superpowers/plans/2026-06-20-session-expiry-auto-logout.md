# Session-Expiry / 401 Auto-Logout (F2.4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a `401` from **any** token-bearing portal call — not just a poll — centrally sign the user out and pause the poller immediately, returning them silently to PIN entry, so an expired/rejected 30-day JWT never strands the user on a broken screen.

**Architecture:** A tiny `@MainActor` `SessionExpiry` mediator in `SlipStreamKit` holds `weak` references to the `AuthStore` and `PollingEngine` and exposes one idempotent `handleUnauthorized()` that pauses the poller (`suspend()`) and signs out. The app composes it once at startup, wires the **same** handler into every `PortalAPIClient`'s existing `onUnauthorized` hook **and** into `PollingEngine.onUnauthorized`, so the poll path and the non-poll path funnel into one place. `AuthStore.signOut()` becomes idempotent so the poll path (which fires *both* the engine's own 401 catch and the client hook for one expired token) can't double-act. Recovery is just "re-enter the PIN" — there is no refresh token — and the return to login is **silent** (no extra messaging), mirroring the web portal.

**Tech Stack:** Swift 6 (strict concurrency), `@Observable` (Observation), Swift Concurrency (`Task`, `@MainActor`, `@Sendable`), Swift Testing, SwiftUI `App`/environment composition, XcodeBuildMCP for the simulator build/run.

## Global Constraints

- **Language/mode:** Swift 6, strict concurrency (`swift-tools-version: 6.0`). Every type crossing a concurrency boundary must be `Sendable`; UI/state types are `@MainActor`.
- **Deployment target:** iOS/iPadOS **26.0** minimum; `SlipStreamKit` also supports **macOS 14** so its pure-logic tests run headlessly via `swift test`. All new kit logic (`SessionExpiry`, `signOut` idempotency) lives in `SlipStreamKit` and **must compile and test on macOS 14** (no SwiftUI import in the kit).
- **No new dependencies, no Xcode project changes:** `SessionExpiry` is added to the existing `SlipStreamKit` target and `SlipStreamKitTests`; the app already links `SlipStreamKit`. No package and no `.xcodeproj`/`Package.swift` edits.
- **Silent expiry UX (resolved 2026-06-20):** a 401 returns the user to the PIN screen with **no extra messaging** (no toast/alert/dedicated screen), exactly like the web portal. The remembered username (F2.1) stays, so re-entry is one PIN away. **Do not add** a `sessionExpiredReason`/messaging field — it is explicitly out of scope.
- **Treat all 401s identically:** a portal client cannot distinguish "expired" from "revoked" (both are a bare `401`; the JWT is stateless with no server-side introspection here), so there is one code path for both. No 401 sub-classification.
- **Scope the hook to token-bearing 401s:** the existing `PortalAPIClient` already fires `onUnauthorized` **only when the request carried a token** (`PortalAPIClient.swift:64`), so a bad-PIN login 401 (no token) stays local to sign-in. F2.4 must preserve this — never sign the user out for a failed login attempt.
- **Commits:** frequent, one per task minimum. Solo repo — commit directly; run `/code-review` then squash-merge to `main`.

---

## Background: what already exists (do not rebuild)

Verified against the current `main` (`0c97531`). F2.4 is a **wiring** feature — most pieces exist:

- `PortalAPIClient` already has a `onUnauthorized: (@Sendable () -> Void)?` hook, fired on any **token-bearing** 401 in `perform(...)` (`Networking/PortalAPIClient.swift:12,17,64-66`). It is **unwired** at the app layer today (clients are built as `PortalAPIClient(baseURL: url)` with no hook — `App/SlipStreamApp.swift:9,21`). F1.2's `PortalAPIClientTests.tokenBearing401FiresUnauthorizedHookOnce` already proves the hook fires once on a token-bearing 401 and *not* on a tokenless one — **do not duplicate that test.**
- `PollingEngine` already catches a poll's `APIClientError.http(401)`, self-suspends, and fires its own `onUnauthorized` (`Polling/PollingEngine.swift:101-103,124-128`). Today the app wires that to `auth.signOut()` directly (`App/SlipStreamApp.swift:27-29`). `PollingEngineTests.unauthorizedPollSuspendsAndNotifies` covers it — **do not duplicate.**
- `AuthStore.restore()` already handles a startup 401 (deletes the JWT, signs out) in its own `catch` (`Auth/AuthStore.swift:62-66`). `AuthStoreTests.restoreWithExpiredTokenDeletesAndSignsOut` covers it — **leave it.** The client hook firing during restore is a harmless idempotent no-op (see Task 3 note).
- `RootView` already resumes the poller on a fresh sign-in (`App/RootView.swift:20` `.onAppear { poller.resume() }`) and clears the poster cache when `auth.state` becomes `.signedOut` (`App/RootView.swift:35`). F2.4 changes none of that behavior — it just makes the *trigger* (a non-poll 401) reach `signedOut`.

**The single gap:** nothing calls `PortalAPIClient.onUnauthorized` to sign out + pause the poller for **non-poll** traffic, and the construction order (`auth` built before `poller`, `system` built as a property initializer) makes a closure that needs *both* awkward to write inline. `SessionExpiry` closes that gap and the construction cycle in one small, testable object.

---

## File structure (this plan)

```
SlipStream-iOS/
  App/
    SlipStreamApp.swift                       # MODIFY: compose SessionExpiry; wire the shared
                                              #   onUnauthorized into both PortalAPIClient factories
                                              #   + PollingEngine; move `system` into init (Task 3)
    RootView.swift                            # MODIFY: refresh the now-stale "F2.4 future" comments (Task 3)
  Packages/SlipStreamKit/
    Sources/SlipStreamKit/Auth/
      AuthStore.swift                         # MODIFY: make signOut() idempotent (Task 1)
    Sources/SlipStreamKit/Session/
      SessionExpiry.swift                     # CREATE: central 401 → suspend + signOut mediator (Task 2)
    Sources/SlipStreamKit/Polling/
      PollingEngine.swift                     # MODIFY: doc-comment only — the hook is now wired (Task 3)
    Tests/SlipStreamKitTests/
      AuthStoreTests.swift                    # MODIFY: add signOut idempotency tests (Task 1)
      SessionExpiryTests.swift                # CREATE: handler suspends + signs out, idempotent, nil-safe (Task 2)
```

**Why a `Session/` folder:** session-lifecycle coordination is its own concern, parallel to `Auth/`, `Networking/`, and `Polling/`. `SessionExpiry` mediates between `AuthStore` and `PollingEngine` without belonging to either, so it sits beside them rather than inside one — matching the established one-responsibility-per-folder `SlipStreamKit` layout.

**External dependencies:** none.

---

### Task 1: Make `AuthStore.signOut()` idempotent

`signOut()` is about to be reachable from two triggers for a single expired token: a poll's 401 makes the `PollingEngine` fire its `onUnauthorized`, **and** that same poll request's `PortalAPIClient` fires its own `onUnauthorized` — both will funnel into `SessionExpiry.handleUnauthorized()` (Task 2/3), so `signOut()` may be called twice in one cycle. Make it a no-op when already signed out, so the second call neither re-deletes the token nor re-publishes `state` (a redundant `@Observable` write would needlessly invalidate observers). This is the smallest, independently-testable invariant the rest of F2.4 leans on, so it lands first. There is no existing `signOut()` unit test — this task adds the first.

**Files:**
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/AuthStore.swift:101-105`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/AuthStoreTests.swift`

**Interfaces:**
- Consumes: existing `AuthStore` (`signIn`, `signOut`, `state`, `currentToken`), `FakeAuthAPI`, `FakeTokenStore`, `sampleUser()` (test helpers in `Fakes.swift`).
- Produces: `AuthStore.signOut()` is idempotent — calling it when `state == .signedOut` performs no token deletion and no state change. Signature unchanged: `public func signOut()`.

- [ ] **Step 1: Write the failing tests**

Add these two tests to `Packages/SlipStreamKit/Tests/SlipStreamKitTests/AuthStoreTests.swift`, inside the `AuthStoreTests` suite (e.g. just before the closing `}` of the suite, after `clearErrorResetsLastError`):

```swift
  @Test func signOutClearsSessionAndDeletesToken() async {
    let api = FakeAuthAPI(
      onLogin: { _ in LoginResponse(token: "tok", user: sampleUser(), isAdmin: false) },
      onProfile: { _ in sampleUser() }
    )
    let tokens = FakeTokenStore()
    let store = makeStore(api: api, tokenStore: tokens)
    await store.signIn(serverURL: serverURL, username: "jack", pin: "1234")
    #expect(store.state == .signedIn(sampleUser()))

    store.signOut()

    #expect(store.state == .signedOut)
    #expect(store.currentToken == nil)
    #expect(tokens.stored == nil)
    #expect(tokens.deleteCount == 1)
  }

  @Test func signOutWhenAlreadySignedOutIsNoOp() {
    let api = FakeAuthAPI(
      onLogin: { _ in throw APIClientError.transport("x") },
      onProfile: { _ in sampleUser() }
    )
    let tokens = FakeTokenStore()
    let store = makeStore(api: api, tokenStore: tokens)
    #expect(store.state == .signedOut)  // fresh store starts signed out

    store.signOut()
    store.signOut()

    #expect(store.state == .signedOut)
    #expect(tokens.deleteCount == 0)  // never touched the keychain — nothing to clear
  }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test --filter AuthStoreTests`
Expected: `signOutWhenAlreadySignedOutIsNoOp` **fails** — today `signOut()` unconditionally calls `tokenStore.delete()`, so `deleteCount == 1`, not `0`. (`signOutClearsSessionAndDeletesToken` already passes — it documents the happy path that must not regress.)

- [ ] **Step 3: Add the idempotency guard**

In `Packages/SlipStreamKit/Sources/SlipStreamKit/Auth/AuthStore.swift`, replace `signOut()` (currently lines 101-105):

```swift
  public func signOut() {
    try? tokenStore.delete()
    token = nil
    state = .signedOut
  }
```

with:

```swift
  /// Clear the session and return to PIN entry. Idempotent: a no-op when already signed out,
  /// so a single expired token reaching both the poll-path and the non-poll client hook
  /// (via `SessionExpiry`) can't re-delete the keychain item or redundantly republish `state`.
  /// Same behavior for a user tap or an auto-logout — the remembered username (F2.1) is kept
  /// either way, so re-entry is one PIN away.
  public func signOut() {
    guard state != .signedOut else { return }
    try? tokenStore.delete()
    token = nil
    state = .signedOut
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test --filter AuthStoreTests`
Expected: all `AuthStoreTests` pass (the existing cases plus the two new ones).

- [ ] **Step 5: Run the full kit suite (no regressions)**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: the whole suite is green (existing count + 2 new tests; no failures).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(kit): make AuthStore.signOut idempotent"
```

---

### Task 2: `SessionExpiry` — the central 401 handler

One small mediator that turns "a token-bearing 401 happened" into "stop polling, return to PIN." It holds `weak` references to the `AuthStore` and `PollingEngine` (weak breaks the retain cycle: the app's `PortalAPIClient` factories capture `SessionExpiry` strongly, and those factories are owned by `AuthStore`/`SystemStore`). The references are settable so the app can wire them **after** constructing the stores — the whole point is to resolve the "clients need `poller`, but `poller` is built after `auth`" ordering. The handler is idempotent by construction: `suspend()` already guards on `isSuspended`, and `signOut()` is idempotent after Task 1.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Session/SessionExpiry.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/SessionExpiryTests.swift`

**Interfaces:**
- Consumes: `AuthStore` (`state`, `signOut()`, `signIn(...)` for test setup), `PollingEngine` (`isSuspended`, `suspend()`, `setActivity(_:)`, `register(_:)` for test setup), `PollStream`, `ParkingScheduler` (test helper in `PollingEngineTests.swift`), `FakeAuthAPI`/`FakeTokenStore`/`FakeServerConfigStore`/`FakeLastUsernameStore`/`sampleUser()` (`Fakes.swift`).
- Produces:
  - `@MainActor public final class SessionExpiry` with:
    - `public init()`
    - `public weak var auth: AuthStore?`
    - `public weak var poller: PollingEngine?`
    - `public func handleUnauthorized()` — `poller?.suspend()` then `auth?.signOut()`.

- [ ] **Step 1: Write the failing tests**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/SessionExpiryTests.swift`:

```swift
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

  @Test func handleUnauthorizedWithoutWiringDoesNotCrash() {
    // weak refs unset (or already deallocated) — the handler must be a safe no-op.
    let expiry = SessionExpiry()
    expiry.handleUnauthorized()
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test --filter SessionExpiryTests`
Expected: compile failure — `cannot find 'SessionExpiry' in scope`.

- [ ] **Step 3: Create `SessionExpiry`**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Session/SessionExpiry.swift`:

```swift
/// Central reaction to an expired or rejected session: a token-bearing `401` from **any**
/// portal call — a background poll or a user-initiated request — pauses polling and signs the
/// user out, returning them to PIN entry. There is no refresh token, so recovery *is* re-entering
/// the PIN; the return to login is silent (no extra messaging), mirroring the web portal.
///
/// It mediates between `AuthStore` and `PollingEngine` without belonging to either. The app wires
/// the same `handleUnauthorized` into every `PortalAPIClient.onUnauthorized` hook and into
/// `PollingEngine.onUnauthorized`, so both the non-poll and poll paths funnel through one place.
///
/// The references are `weak` and settable so the app can assign them **after** building the stores
/// — resolving the construction cycle (the clients need the poller, but the poller is built after
/// the auth store) and avoiding a retain cycle (the client factories capture `self` strongly and
/// are owned by the stores).
@MainActor
public final class SessionExpiry {
  public weak var auth: AuthStore?
  public weak var poller: PollingEngine?

  public init() {}

  /// Pause polling immediately, then sign out. Idempotent: `PollingEngine.suspend()` guards on
  /// `isSuspended` and `AuthStore.signOut()` is a no-op once signed out, so a single expired token
  /// reaching both the poll path and the client hook reacts exactly once. Suspending *before*
  /// signing out stops a burst of in-flight polls from piling up during the transition.
  public func handleUnauthorized() {
    poller?.suspend()
    auth?.signOut()
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test --filter SessionExpiryTests`
Expected: all three `SessionExpiryTests` pass.

- [ ] **Step 5: Run the full kit suite (no regressions)**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: green (Task 1's count + 3 new tests).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(kit): add SessionExpiry central 401 handler"
```

---

### Task 3: App wiring + simulator no-regression verification

Compose `SessionExpiry` once at startup and route every 401 source through it: build a single shared `@Sendable` `onUnauthorized` closure, inject it into the `PortalAPIClient` factories for **both** `AuthStore` (login/restore) and `SystemStore` (status), and into `PollingEngine`. To give the `system` factory access to the closure, move `system`'s construction from a property initializer into `init()` (it currently builds its client with no hook at `SlipStreamApp.swift:8-11`). Refresh the now-stale "F2.4 expands the recovery UX / future 401 auto-logout" comments in `SlipStreamApp.swift`, `RootView.swift`, and `PollingEngine.swift` to describe the shipped wiring. No `.xcodeproj`/`Package.swift` change — `SlipStreamKit` is already linked and `SessionExpiry` is part of it.

A live 401 can't be forced on the simulator (the dev-server JWT is long-lived, like F1.5's note), so the headless tests from Tasks 1–2 plus F1.2/F1.5's existing hook tests are the gate. The simulator pass here only confirms the rewired composition still builds and the **normal** sign-in → shell → sign-out loop is unaffected.

**Files:**
- Modify: `App/SlipStreamApp.swift`
- Modify: `App/RootView.swift:17-19` (comment refresh) and `:33-34` (comment refresh)
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollingEngine.swift:119-123` (comment refresh)

**Interfaces:**
- Consumes: `SessionExpiry` (Task 2), `AuthStore`, `SystemStore`, `PollingEngine`, `PortalAPIClient`, `KeychainTokenStore`, `UserDefaultsServerConfigStore`, `UserDefaultsLastUsernameStore` (all existing in `SlipStreamKit`); `DesignTheme.bootstrap()`.
- Produces: the running app — every token-bearing 401 now routes through `SessionExpiry`. No downstream code consumers in this plan.

- [ ] **Step 1: Rewire the app entry point**

Replace `App/SlipStreamApp.swift` in full:

```swift
import DesignSystem
import SlipStreamKit
import SwiftUI

@main
struct SlipStreamApp: App {
  @State private var auth: AuthStore
  @State private var system: SystemStore
  @State private var poller: PollingEngine
  @State private var navigation = NavigationModel()
  @State private var posterSize = PosterSizePreference(store: UserDefaultsPosterSizeStore())

  init() {
    // Install the Nuke poster pipeline (and the Inter typeface) before any view renders.
    DesignTheme.bootstrap()

    // Central session-expiry handler. A token-bearing 401 from any portal call routes here to
    // pause the poller and sign out (F2.4). `auth`/`poller` are assigned after the stores exist
    // — they reference each other, so the wiring is two-phase. (`PortalAPIClient.onUnauthorized`
    // already fires only for token-bearing 401s, so a bad-PIN login never triggers it.)
    let expiry = SessionExpiry()
    let onUnauthorized: @Sendable () -> Void = { Task { @MainActor in expiry.handleUnauthorized() } }

    let initialAuth = AuthStore(
      makeAuthAPI: { url in PortalAPIClient(baseURL: url, onUnauthorized: onUnauthorized) },
      tokenStore: KeychainTokenStore(),
      serverConfig: UserDefaultsServerConfigStore(),
      lastUsernameStore: UserDefaultsLastUsernameStore()
    )
    let initialSystem = SystemStore(
      makeSystemAPI: { url in PortalAPIClient(baseURL: url, onUnauthorized: onUnauthorized) },
      serverConfig: UserDefaultsServerConfigStore()
    )
    // A 401 from a poll also routes through the same handler (the engine additionally self-suspends
    // and stops its drivers; suspend() is then a guarded no-op here).
    let initialPoller = PollingEngine(onUnauthorized: { expiry.handleUnauthorized() })

    expiry.auth = initialAuth
    expiry.poller = initialPoller

    _auth = State(initialValue: initialAuth)
    _system = State(initialValue: initialSystem)
    _poller = State(initialValue: initialPoller)
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(system)
        .environment(poller)
        .environment(navigation)
        .environment(posterSize)
        .preferredColorScheme(.dark)
    }
  }
}
```

- [ ] **Step 2: Refresh the stale comments in `RootView`**

In `App/RootView.swift`, the resume comment (currently lines 17-19) and the cache-clear comment (currently lines 33-34) both say F2.4 is "future." Update them to present tense.

Replace:

```swift
        // Re-enable polling on a fresh sign-in: a prior 401 suspends the engine
        // (PollingEngine.handleUnauthorized) and only resume() clears it. (F2.4
        // expands the recovery UX.)
        .onAppear { poller.resume() }
```

with:

```swift
        // Re-enable polling on a fresh sign-in: a 401 auto-logout suspends the engine
        // (via SessionExpiry) and only resume() clears it. (F2.4)
        .onAppear { poller.resume() }
```

Replace:

```swift
    // Drop cached poster artwork whenever the session ends — manual sign-out or
    // F2.4's future 401 auto-logout. Shared family device. (F1.7)
    .onChange(of: auth.state) { _, state in
```

with:

```swift
    // Drop cached poster artwork whenever the session ends — manual sign-out or
    // a 401 auto-logout (F2.4, via SessionExpiry). Shared family device. (F1.7)
    .onChange(of: auth.state) { _, state in
```

- [ ] **Step 3: Refresh the `PollingEngine` doc comment**

In `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollingEngine.swift`, the `handleUnauthorized` doc (currently lines 119-123) says the client hook is "unwired today." Replace that doc comment:

```swift
  /// A poll came back 401: the JWT expired or was rejected. Stop everything and tell the app.
  ///
  /// The engine owns the 401 for *poll* traffic. `PortalAPIClient` has its own `onUnauthorized`
  /// hook for non-poll requests; it is unwired today. When F2.4 wires it, scope it to non-poll
  /// calls so a single expired token doesn't trigger two sign-outs for the same poll cycle.
  private func handleUnauthorized() {
```

with:

```swift
  /// A poll came back 401: the JWT expired or was rejected. Stop everything and tell the app.
  ///
  /// The engine owns the 401 for *poll* traffic. `PortalAPIClient` owns it for non-poll requests
  /// via its own `onUnauthorized` hook; F2.4 funnels both into `SessionExpiry`. A single expired
  /// token can reach both paths in one poll cycle, which is safe — `SessionExpiry.handleUnauthorized`
  /// is idempotent (`suspend()` and `AuthStore.signOut()` both no-op when already applied).
  private func handleUnauthorized() {
```

- [ ] **Step 4: Confirm the kit suite is still green**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: green — the app rewiring doesn't touch `SlipStreamKit` sources except the `PollingEngine` doc comment (comments don't affect tests).

- [ ] **Step 5: Lint the changed files**

Run: `make lint`
Expected: no swift-format or SwiftLint violations in the changed files. If swift-format reports formatting, run `make format` and re-stage.

- [ ] **Step 6: Build and run on the simulator**

Confirm defaults first, then build/run:

```
mcp__xcodebuildmcp__session_show_defaults
mcp__xcodebuildmcp__build_run_sim   (empty args if defaults show SlipStream + iPhone 17)
```

Expected: `BUILD SUCCEEDED`; the app launches to "Unlocking…" then the sign-in form.

- [ ] **Step 7: Manual no-regression verification**

Use the dev server per the `test-with-dev-server` skill (`Jackson` / `8472`). Verify the normal loop is unaffected by the rewiring:
- Sign in. Expected: reach the signed-in shell (tab bar on iPhone).
- Tap **Sign Out** (Settings tab). Expected: return to the sign-in form with the username remembered as a chip (F2.1).
- Sign in again. Expected: back to the shell — polling resumes (`RootView`'s `.onAppear { poller.resume() }`).

> The 401 → suspend → signOut path itself is covered deterministically by `SessionExpiryTests` (Task 2) and the existing `PortalAPIClientTests`/`PollingEngineTests` hook tests. Forcing a live 401 is impractical (30-day JWT) — the unit tests are the gate, exactly as F1.5 established for its 401 path.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(app): route all 401s through SessionExpiry auto-logout"
```

---

## Self-Review

**1. Spec coverage** (against `session-expiry-auto-logout.md` "In scope"):
- "Central `401` handler (fed by the API client) → clear token, sign out, route to PIN." → `SessionExpiry.handleUnauthorized` wired into both `PortalAPIClient` factories' `onUnauthorized` (Task 2 creates it, Task 3 wires it). `signOut()` clears the token + state; `AuthGateView` routes `.signedOut` → `SignInView`. ✓
- "Pause/stop the poller on the first `401`." → `handleUnauthorized` calls `poller.suspend()` *before* `signOut()`; the poll path additionally self-suspends in the engine. Verified by `SessionExpiryTests.handleUnauthorizedSuspendsPollerAndSignsOut`. ✓
- "Optional explicit 'session expired' messaging vs a silent return." → **resolved silent** (Global Constraints); no messaging state added. ✓
- Open question "explicit screen vs silent" → silent (matches web). ✓
- Open question "distinguish expired vs revoked" → no; one path for both (Global Constraints). ✓
- "Subscribe to the API client's 401 signal centrally; pause the poller at once." (iOS notes) → exactly the `SessionExpiry` design. ✓
- Dependencies (API client, polling engine, session persistence) all already present; F2.4 only connects them. ✓

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N". Every code step shows complete code; every command states expected output. The one deferred verification (live 401) is explicitly justified and covered by unit tests. ✓

**3. Type consistency:** Names match across tasks and the app wiring — `SessionExpiry` with `auth`/`poller`/`handleUnauthorized()` (Task 2) is used verbatim in `SlipStreamApp` (Task 3). `PortalAPIClient(baseURL:onUnauthorized:)`, `PollingEngine(scheduler:onUnauthorized:)`, `AuthStore(makeAuthAPI:tokenStore:serverConfig:lastUsernameStore:)`, `SystemStore(makeSystemAPI:serverConfig:)` all match the current sources. `signOut()` signature unchanged. Test helpers reused exactly: `FakeAuthAPI(onLogin:onProfile:)`, `FakeTokenStore` (`stored`/`deleteCount`), `ParkingScheduler` (from `PollingEngineTests.swift`), `sampleUser()`. ✓

**Notes for the implementer:**
- Run Tasks 1–2 with `swift test` in `Packages/SlipStreamKit` (fast, no simulator). Task 3 uses XcodeBuildMCP for a build + no-regression pass.
- `ParkingScheduler` lives in `PollingEngineTests.swift` (same `SlipStreamKitTests` target), so `SessionExpiryTests` can use it directly — no need to redeclare it.
- The shared `onUnauthorized` for `PortalAPIClient` must hop to the main actor (`Task { @MainActor in ... }`): the client's hook is `(@Sendable () -> Void)?` invoked off the main actor, whereas `SessionExpiry` is `@MainActor`. The `PollingEngine` hook is already `@MainActor () -> Void`, so it calls `expiry.handleUnauthorized()` directly.
- `SessionExpiry`'s `auth`/`poller` are `weak`; they're kept alive by the app's `@State`, so the weak refs stay valid for the app's lifetime. The strong capture is `SessionExpiry` ← the factory closures ← the stores, so there is no cycle.
- During `restore()`, a startup 401 fires the client hook (schedules `handleUnauthorized`) *and* runs `restore()`'s own `catch`. Both sign out; the idempotent `signOut()` (Task 1) makes the second a no-op. Leave `restore()`'s explicit `catch` as-is — it remains the primary, synchronous handler there.
- After merging, update `docs/TRACKER.md`: change F2.4 from `[ ] ◑` to `[x]`, drop the "◑ Plan 1: restore-path 401 done" qualifier, and add an F2.4 entry under "## Plans" pointing at this file. Resolve the spec's two open questions (silent return; one path for both 401 kinds).

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-20-session-expiry-auto-logout.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.
