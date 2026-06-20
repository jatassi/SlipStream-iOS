# Real-time Polling Engine (F1.5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a shared, headlessly-tested `PollingEngine` in `SlipStreamKit` that refetches active views on a per-stream interval while the app is foregrounded, pauses in the background, suspends immediately on a `401`, and gates each stream behind an enable predicate — the portal's substitute for websockets.

**Architecture:** One `@MainActor @Observable PollingEngine` owns a registry of `PollStream`s (each = id + interval + enable-gate + async `perform`). The engine starts a per-stream driver `Task` when the stream *should run* (app `.active`, not suspended, gate open) and cancels it otherwise. All timing flows through an injected `PollScheduler` seam so the engine is unit-tested deterministically with no wall-clock waiting and no network. The app maps SwiftUI `scenePhase` → `PollingActivity` to drive start/stop, and wires the engine's `onUnauthorized` hook to `AuthStore.signOut()`. F1.5 ships the *engine* plus a throwaway counter stream that visibly proves the lifecycle on the simulator; later features (F4.2 request list, F5.1 downloads strip) register their own real streams.

**Tech Stack:** Swift 6 (strict concurrency), `@Observable` (Observation), Swift Concurrency (`Task`, `Duration`, `Task.sleep(for:)`, `AsyncStream`), Swift Testing, SwiftUI `scenePhase`, XcodeBuildMCP for the simulator build/run.

## Global Constraints

- **Language/mode:** Swift 6, strict concurrency (`swift-tools-version: 6.0`). Every type crossing a concurrency boundary must be `Sendable`; UI/state types are `@MainActor`.
- **Deployment target:** iOS/iPadOS **26.0** minimum. `SlipStreamKit` additionally supports **macOS 14** so its pure-logic tests run via `swift test`. The polling engine lives in `SlipStreamKit` and **must compile and test on macOS 14** (no SwiftUI/`ScenePhase` import in the kit — the app does the `scenePhase` mapping).
- **No websocket, no server change:** the engine polls the same REST endpoints. The server `/ws` is admin-audience only and is out of scope.
- **Cadence (resolves TRACKER open question #5):** interval is **per-stream and configurable**, so the "uniform 3s vs web's 5s/3s split" choice is a caller decision, not an engine decision. The engine imposes no single cadence. The demonstration stream in this plan polls every **3s** (the project target for live views); F4.2 may register its request stream at 5s and F5.1 its downloads stream at 3s without any engine change.
- **Background behavior (resolves the spec's second open question):** **hard-stop.** Both `.inactive` and `.background` stop all drivers (no slow heartbeat). Only `.active` polls.
- **401 policy:** a poll that throws `APIClientError.http(status: 401, …)` makes the engine **suspend immediately** (cancels every driver, sets `isSuspended = true`) and fire `onUnauthorized`. Resuming requires an explicit `resume()` (the app re-enables after a fresh sign-in). Full re-prompt/recovery UX is **F2.4's** scope; F1.5 only provides the suspend + hook seam, wired here to `signOut()`.
- **Gating:** each stream carries an `isEnabled` predicate; download polling will gate on active-request existence via this predicate (`isEnabled: { hasActiveRequests }`) — F5.1's job. F1.5 unit-tests the gate mechanism generically.
- **No new dependencies, no Xcode project changes:** the engine is added to the existing `SlipStreamKit` target and the existing `SlipStreamKitTests` target; the app already links `SlipStreamKit`. No package is added.
- **Commits:** frequent, one per task minimum. Solo repo — commit directly; squash-merge to `main` after `/code-review`.

---

## File structure (this plan)

```
SlipStream-iOS/
  App/
    SlipStreamApp.swift                     # MODIFY: compose PollingEngine, wire onUnauthorized → signOut (Task 3)
    RootView.swift                          # MODIFY: map scenePhase → engine.setActivity (Task 3)
    SignedInPlaceholderView.swift           # MODIFY: register/unregister a demo heartbeat stream (Task 3)
  Packages/SlipStreamKit/
    Sources/SlipStreamKit/Polling/
      PollingActivity.swift                 # CREATE: active/inactive/background lifecycle input (Task 1)
      PollScheduler.swift                   # CREATE: sleep seam + ContinuousClockScheduler (Task 1)
      PollStream.swift                      # CREATE: id + interval + isEnabled + perform (Task 1)
      PollingEngine.swift                   # CREATE: registry + driver lifecycle + gating (Task 1); 401 (Task 2)
    Tests/SlipStreamKitTests/
      PollingEngineTests.swift              # CREATE: ParkingScheduler + lifecycle/gate/suspend tests (Task 1); 401 test (Task 2)
```

**Why a `Polling/` folder:** the engine is its own concern, parallel to `Networking/` and `Auth/`. Keeping the four small files together (one responsibility each — lifecycle enum, scheduler seam, stream value, engine) matches the established `SlipStreamKit` layout.

**External dependencies:** none.

---

### Task 1: PollingEngine core — primitives, lifecycle, gating, suspend/resume

The whole engine *except* the 401 path. Deliverable: a headlessly-tested `PollingEngine` that starts a per-stream driver when the app is `.active`, not suspended, and the stream's gate is open; stops it otherwise; and re-evaluates gates on demand and after every poll. All deterministic — no wall-clock waiting (a "parking" scheduler makes each stream poll exactly once per activation so tests observe a single, repeatable poll).

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollingActivity.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollScheduler.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollStream.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollingEngine.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PollingEngineTests.swift`

**Interfaces:**
- Consumes: nothing (generic; the 401 path in Task 2 will consume `APIClientError`).
- Produces:
  - `enum PollingActivity: Sendable { case active; case inactive; case background }`
  - `protocol PollScheduler: Sendable { func sleep(for interval: Duration) async throws }` + `struct ContinuousClockScheduler: PollScheduler`.
  - `struct PollStream: Sendable` with `init(id: String, interval: Duration, isEnabled: @escaping @MainActor () -> Bool = { true }, perform: @escaping @MainActor () async throws -> Void)`.
  - `@MainActor @Observable final class PollingEngine` with:
    - `init(scheduler: PollScheduler = ContinuousClockScheduler())`
    - `var activity: PollingActivity` (read-only), `var isSuspended: Bool` (read-only)
    - `func register(_ stream: PollStream)`, `func unregister(id: String)`
    - `func setActivity(_ activity: PollingActivity)`, `func suspend()`, `func resume()`, `func reevaluate()`
    - `func isRunning(streamID: String) -> Bool`

- [ ] **Step 1: Write the failing engine tests**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PollingEngineTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

/// A scheduler that parks "forever" (until the driver task is cancelled), so each stream
/// performs exactly once per activation. That single, buffered poll lets tests await a
/// deterministic signal instead of racing a wall clock.
struct ParkingScheduler: PollScheduler {
    func sleep(for interval: Duration) async throws {
        try await Task.sleep(for: .seconds(3600))
    }
}

@MainActor
@Suite struct PollingEngineTests {

    @Test func idleEngineRunsNothing() {
        var performed = 0
        let engine = PollingEngine(scheduler: ParkingScheduler())
        engine.register(PollStream(id: "x", interval: .seconds(3), perform: {
            performed += 1
        }))
        // Engine starts .inactive; nothing should run.
        #expect(engine.isRunning(streamID: "x") == false)
        #expect(performed == 0)
    }

    @Test func activatingStartsStreamAndBackgroundStops() async {
        let signal = AsyncStream<Void>.makeStream(of: Void.self)
        let engine = PollingEngine(scheduler: ParkingScheduler())
        engine.register(PollStream(id: "x", interval: .seconds(3), perform: {
            signal.continuation.yield()
        }))

        engine.setActivity(.active)
        var it = signal.stream.makeAsyncIterator()
        await it.next()                                  // deterministic: first poll happened
        #expect(engine.isRunning(streamID: "x"))

        engine.setActivity(.background)
        #expect(engine.isRunning(streamID: "x") == false)
    }

    @Test func disabledGateDoesNotRunUntilEnabled() async {
        let signal = AsyncStream<Void>.makeStream(of: Void.self)
        var enabled = false
        let engine = PollingEngine(scheduler: ParkingScheduler())
        engine.register(PollStream(
            id: "downloads",
            interval: .seconds(3),
            isEnabled: { enabled },
            perform: { signal.continuation.yield() }
        ))

        engine.setActivity(.active)
        #expect(engine.isRunning(streamID: "downloads") == false)   // gate closed → no traffic

        enabled = true
        engine.reevaluate()
        var it = signal.stream.makeAsyncIterator()
        await it.next()
        #expect(engine.isRunning(streamID: "downloads"))
    }

    @Test func suspendStopsAndResumeRestarts() async {
        let signal = AsyncStream<Void>.makeStream(of: Void.self)
        let engine = PollingEngine(scheduler: ParkingScheduler())
        engine.register(PollStream(id: "x", interval: .seconds(3), perform: {
            signal.continuation.yield()
        }))

        engine.setActivity(.active)
        var it = signal.stream.makeAsyncIterator()
        await it.next()
        #expect(engine.isRunning(streamID: "x"))

        engine.suspend()
        #expect(engine.isSuspended)
        #expect(engine.isRunning(streamID: "x") == false)

        engine.resume()
        await it.next()                                  // polls again after resume
        #expect(engine.isSuspended == false)
        #expect(engine.isRunning(streamID: "x"))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'PollingEngine' in scope` (and `PollStream`, `PollScheduler`).

- [ ] **Step 3: Write the primitives**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollingActivity.swift`:

```swift
/// The app's foreground state, mapped from SwiftUI's `ScenePhase` by the app layer so the
/// engine stays UI-framework-agnostic (and testable on macOS without SwiftUI). Only `.active`
/// polls; `.inactive` and `.background` hard-stop every driver.
public enum PollingActivity: Sendable {
    case active
    case inactive
    case background
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollScheduler.swift`:

```swift
/// Timing seam for the poll loop. Injected so tests drive iterations deterministically
/// without waiting on a real clock. Implementations must throw `CancellationError` when the
/// calling task is cancelled (so cancelling a driver promptly exits its loop).
public protocol PollScheduler: Sendable {
    func sleep(for interval: Duration) async throws
}

/// Production scheduler backed by `Task.sleep(for:)` (ContinuousClock; cancellation-aware).
public struct ContinuousClockScheduler: PollScheduler {
    public init() {}

    public func sleep(for interval: Duration) async throws {
        try await Task.sleep(for: interval)
    }
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollStream.swift`:

```swift
/// One pollable view's policy: a stable `id`, a refresh `interval`, an `isEnabled` gate
/// (e.g. download polling is gated on active requests existing), and the async `perform`
/// that fetches. The closures are `@MainActor`, so a stream is `Sendable` (a global-actor
/// closure is Sendable) and safe to hand to the engine's driver tasks.
public struct PollStream: Sendable {
    public let id: String
    public let interval: Duration
    public let isEnabled: @MainActor () -> Bool
    public let perform: @MainActor () async throws -> Void

    public init(
        id: String,
        interval: Duration,
        isEnabled: @escaping @MainActor () -> Bool = { true },
        perform: @escaping @MainActor () async throws -> Void
    ) {
        self.id = id
        self.interval = interval
        self.isEnabled = isEnabled
        self.perform = perform
    }
}
```

- [ ] **Step 4: Write the engine**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollingEngine.swift`:

```swift
import Observation

/// Shared, foreground-gated poller — the portal's substitute for websockets. Screens register
/// a `PollStream`; the engine runs each stream's driver only while the app is `.active`, not
/// suspended, and the stream's gate is open, and cancels it otherwise. All timing flows through
/// an injected `PollScheduler` so the engine is unit-tested without a real clock.
@MainActor
@Observable
public final class PollingEngine {
    public private(set) var activity: PollingActivity = .inactive
    public private(set) var isSuspended = false

    @ObservationIgnored private let scheduler: PollScheduler
    @ObservationIgnored private var streams: [String: PollStream] = [:]
    @ObservationIgnored private var running: Set<String> = []
    @ObservationIgnored private var drivers: [String: Task<Void, Never>] = [:]

    public init(scheduler: PollScheduler = ContinuousClockScheduler()) {
        self.scheduler = scheduler
    }

    // MARK: Registration

    public func register(_ stream: PollStream) {
        streams[stream.id] = stream
        reevaluate()
    }

    public func unregister(id: String) {
        streams[id] = nil
        running.remove(id)
        stopDriver(id: id)
    }

    // MARK: Lifecycle

    public func setActivity(_ activity: PollingActivity) {
        self.activity = activity
        reevaluate()
    }

    /// Pause all polling immediately — no traffic until `resume()`. Used on a `401`.
    public func suspend() {
        guard !isSuspended else { return }
        isSuspended = true
        reevaluate()
    }

    public func resume() {
        guard isSuspended else { return }
        isSuspended = false
        reevaluate()
    }

    public func isRunning(streamID: String) -> Bool {
        running.contains(streamID)
    }

    /// Re-check every stream's gate + lifecycle and start/stop drivers to match. Called after
    /// lifecycle changes, after every poll (so a stream that just changed shared state can
    /// start/stop its peers), and on demand by callers that mutate a gate's inputs.
    public func reevaluate() {
        for (id, stream) in streams {
            let want = shouldRun(stream)
            if want && !running.contains(id) {
                running.insert(id)
                startDriver(for: stream)
            } else if !want && running.contains(id) {
                running.remove(id)
                stopDriver(id: id)
            }
        }
    }

    // MARK: Internals

    private func shouldRun(_ stream: PollStream) -> Bool {
        activity == .active && !isSuspended && stream.isEnabled()
    }

    private func startDriver(for stream: PollStream) {
        drivers[stream.id] = Task { @MainActor [weak self] in
            await self?.run(stream)
        }
    }

    private func stopDriver(id: String) {
        drivers[id]?.cancel()
        drivers[id] = nil
    }

    private func run(_ stream: PollStream) async {
        while running.contains(stream.id) && !Task.isCancelled {
            do {
                try await stream.perform()
            } catch is CancellationError {
                return
            } catch {
                // Transient failure (network blip, decode): keep polling on the next tick.
            }
            reevaluate()                                   // ripple shared-state changes to peers
            guard running.contains(stream.id) else { return }
            do {
                try await scheduler.sleep(for: stream.interval)
            } catch {
                return                                     // cancelled while sleeping
            }
        }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (the 4 new `PollingEngineTests` plus the existing 11 = 15 total, no failures).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(kit): add PollingEngine with lifecycle and gating"
```

---

### Task 2: Suspend on 401 + onUnauthorized hook

The error-handling policy: a poll that returns `401` means the 30-day JWT expired or was rejected. The engine must suspend immediately and notify the app so it can sign out. This is a separable concern from the core lifecycle — a reviewer could accept Task 1 and still reject the 401 semantics — so it gets its own task and test.

**Files:**
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollingEngine.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PollingEngineTests.swift` (add one test)

**Interfaces:**
- Consumes: `APIClientError` (from `SlipStreamKit/Networking/APIError.swift`).
- Produces (additive — Task 1 callers are unaffected because the new init param is defaulted):
  - `PollingEngine.init(scheduler: PollScheduler = ContinuousClockScheduler(), onUnauthorized: @escaping @MainActor () -> Void = {})`

- [ ] **Step 1: Write the failing 401 test**

Add this test to `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PollingEngineTests.swift`, inside the `PollingEngineTests` suite (after `suspendStopsAndResumeRestarts`):

```swift
    @Test func unauthorizedPollSuspendsAndNotifies() async {
        let authSignal = AsyncStream<Void>.makeStream(of: Void.self)
        let engine = PollingEngine(
            scheduler: ParkingScheduler(),
            onUnauthorized: { authSignal.continuation.yield() }
        )
        engine.register(PollStream(id: "x", interval: .seconds(3), perform: {
            throw APIClientError.http(status: 401, message: nil, error: nil)
        }))

        engine.setActivity(.active)
        var it = authSignal.stream.makeAsyncIterator()
        await it.next()                                  // engine handled the 401
        #expect(engine.isSuspended)
        #expect(engine.isRunning(streamID: "x") == false)
    }
```

- [ ] **Step 2: Run the tests to verify the new one fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: a **compile error** — `extra argument 'onUnauthorized' in call` — because the Task 1 `init` has no `onUnauthorized` parameter. (Even once the parameter exists, before the 401 catch clause is added the perform's `401` is swallowed by the generic `catch`, so `onUnauthorized` would never fire and the `await it.next()` would hang.) Either way: red before green. Fix in Step 3.

- [ ] **Step 3: Add the onUnauthorized parameter and 401 handling**

In `Packages/SlipStreamKit/Sources/SlipStreamKit/Polling/PollingEngine.swift`, replace the stored `scheduler` declaration and `init` with:

```swift
    @ObservationIgnored private let scheduler: PollScheduler
    @ObservationIgnored private let onUnauthorized: @MainActor () -> Void
    @ObservationIgnored private var streams: [String: PollStream] = [:]
    @ObservationIgnored private var running: Set<String> = []
    @ObservationIgnored private var drivers: [String: Task<Void, Never>] = [:]

    public init(
        scheduler: PollScheduler = ContinuousClockScheduler(),
        onUnauthorized: @escaping @MainActor () -> Void = {}
    ) {
        self.scheduler = scheduler
        self.onUnauthorized = onUnauthorized
    }
```

Then, in `run(_:)`, insert a `401` catch clause **before** the generic `catch`:

```swift
            do {
                try await stream.perform()
            } catch let APIClientError.http(status, _, _) where status == 401 {
                handleUnauthorized()
                return
            } catch is CancellationError {
                return
            } catch {
                // Transient failure (network blip, decode): keep polling on the next tick.
            }
```

Finally, add this private method to `PollingEngine` (e.g. just after `run(_:)`):

```swift
    /// A poll came back 401: the JWT expired or was rejected. Stop everything and tell the app.
    private func handleUnauthorized() {
        isSuspended = true
        reevaluate()            // shouldRun is now false for all streams → cancels every driver
        onUnauthorized()
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (16 total — the 5 `PollingEngineTests` plus the existing 11).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): suspend polling and notify on 401"
```

---

### Task 3: App integration + simulator verification

Wire the engine into the app: compose it alongside `AuthStore`, map `scenePhase` to `setActivity`, route `onUnauthorized` → `signOut()`, and register a throwaway counter stream in the signed-in placeholder so the lifecycle is visible on the simulator. Verified by building/running and watching the counter tick every ~3s, pause when backgrounded, and resume when foregrounded. No Xcode project change — `SlipStreamKit` is already linked and `PollingEngine` is part of it.

**Files:**
- Modify: `App/SlipStreamApp.swift`
- Modify: `App/RootView.swift`
- Modify: `App/SignedInPlaceholderView.swift`

**Interfaces:**
- Consumes: `PollingEngine`, `PollStream`, `PollingActivity`, `AuthStore` (SlipStreamKit); `AuthGateView`, `SignedInPlaceholderView` (existing).
- Produces: the running app exercising the engine (no downstream consumers in this plan).

- [ ] **Step 1: Compose the engine in the app entry point**

Replace `App/SlipStreamApp.swift` with:

```swift
import SwiftUI
import SlipStreamKit

@main
struct SlipStreamApp: App {
    @State private var auth: AuthStore
    @State private var poller: PollingEngine

    init() {
        let auth = AuthStore(
            makeAuthAPI: { url in PortalAPIClient(baseURL: url) },
            tokenStore: KeychainTokenStore(),
            serverConfig: UserDefaultsServerConfigStore()
        )
        // A 401 from any poll means the JWT expired: sign out. (F2.4 expands the recovery UX.)
        let poller = PollingEngine(onUnauthorized: { [weak auth] in
            Task { await auth?.signOut() }
        })
        _auth = State(initialValue: auth)
        _poller = State(initialValue: poller)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(poller)
        }
    }
}
```

- [ ] **Step 2: Map scenePhase to the engine in RootView**

Replace `App/RootView.swift` with:

```swift
import SwiftUI
import SlipStreamKit
import FeatureAuth

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PollingEngine.self) private var poller

    var body: some View {
        AuthGateView {
            SignedInPlaceholderView()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            poller.setActivity(activity(for: phase))
        }
    }

    private func activity(for phase: ScenePhase) -> PollingActivity {
        switch phase {
        case .active: .active
        case .inactive: .inactive
        case .background: .background
        @unknown default: .inactive
        }
    }
}
```

- [ ] **Step 3: Register a demo heartbeat stream in the placeholder**

Replace `App/SignedInPlaceholderView.swift` with:

```swift
import SwiftUI
import SlipStreamKit

/// A throwaway `@Observable` that the demo poll stream increments — proves the engine ticks
/// while foregrounded and pauses in the background. Real features replace this with fetched data.
@MainActor
@Observable
final class PollHeartbeat {
    var count = 0
}

/// Placeholder proving auth + polling work end-to-end. Replaced by the library browse UI later.
struct SignedInPlaceholderView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(PollingEngine.self) private var poller
    @State private var heartbeat = PollHeartbeat()

    var body: some View {
        VStack(spacing: 16) {
            if case let .signedIn(user) = auth.state {
                Text("Signed in as \(user.username)").font(.headline)
                Text(user.autoApprove ? "Auto-approve: on" : "Auto-approve: off")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Polls: \(heartbeat.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button("Sign Out") {
                Task { await auth.signOut() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            poller.register(PollStream(
                id: "demo-heartbeat",
                interval: .seconds(3),
                perform: { heartbeat.count += 1 }
            ))
        }
        .onDisappear {
            poller.unregister(id: "demo-heartbeat")
        }
    }
}
```

- [ ] **Step 4: Build and run on the simulator**

```
mcp__xcodebuildmcp__build_run_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED` and the app launches to the sign-in form after a brief "Unlocking…".

- [ ] **Step 5: Manual lifecycle verification**

Sign in (HTTPS URL + real portal username + 4-digit PIN; set Features → Face ID → Enrolled first). Expected: the signed-in screen shows "Polls: N" with **N incrementing roughly every 3 seconds**. Then:
- **Background the app** (swipe to the home screen). Expected: the count freezes — backgrounding maps to `.background`, which stops the driver.
- **Foreground the app**. Expected: the count resumes incrementing every ~3s.
- **Tap Sign Out**. Expected: back to the sign-in form (the placeholder's `onDisappear` unregisters the stream — no further ticks).

If the cadence looks wrong, capture logs:

```
mcp__xcodebuildmcp__start_sim_log_cap   (then reproduce, then stop_sim_log_cap)
```

> The `401 → suspend → signOut` path is covered deterministically by `unauthorizedPollSuspendsAndNotifies` (Task 2). It is impractical to force a live 401 here (the JWT lasts 30 days), so it is not part of the manual script — the unit test is the gate.

- [ ] **Step 6: Confirm the headless suite is still green**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: 16 tests pass (no regressions from the app wiring — the app changes don't touch `SlipStreamKit`).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(app): drive PollingEngine from scenePhase"
```

---

## Self-Review

**1. Spec coverage** (against `polling-engine.md` "In scope" + TRACKER open questions):
- "One poller policy shared by all active screens" → single `PollingEngine` registered into the environment; screens register `PollStream`s (Tasks 1, 3). ✓
- "Cadence … project target is ~3s" + open question #5 (uniform vs split) → per-stream configurable `interval`; demo uses 3s; question resolved as a caller decision in Global Constraints. ✓
- "Start/stop on `scenePhase` (pause in background)" → `PollingActivity` + `setActivity`, mapped from `scenePhase` in `RootView`; only `.active` runs (Tasks 1, 3). ✓
- "pause immediately on a `401`" → Task 2 `handleUnauthorized` suspends + notifies; verified by `unauthorizedPollSuspendsAndNotifies`. ✓
- "Gate download polling on active-request existence" → `PollStream.isEnabled` predicate + `reevaluate`; verified by `disabledGateDoesNotRunUntilEnabled` (F5.1 will pass `{ hasActiveRequests }`). ✓
- "don't poll an idle app" → `idleEngineRunsNothing` (no `.active`, no driver); gate keeps idle streams quiet. ✓
- Background-behavior open question → resolved as hard-stop in Global Constraints; `.inactive`/`.background` both stop. ✓
- "no websocket / no server change" → engine is REST-only; no `/ws`; no new dependency. ✓

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N". Every code step shows complete code; every command states expected output. Task 2's red step is explicitly characterized (compile error vs. swallowed-401), not vague. The only deferred verification (live 401) is explicitly justified and covered by a unit test. ✓

**3. Type consistency:** Names match across tasks and the app wiring — `PollingActivity` (`.active/.inactive/.background`), `PollScheduler.sleep(for:)`, `ContinuousClockScheduler`, `PollStream(id:interval:isEnabled:perform:)`, `PollingEngine` members `activity / isSuspended / register / unregister(id:) / setActivity / suspend / resume / reevaluate / isRunning(streamID:)`, and the Task 2 `init(scheduler:onUnauthorized:)`. The app uses exactly these: `setActivity(activity(for:))`, `register(PollStream(...))`, `unregister(id:)`, `PollingEngine(onUnauthorized:)`. `APIClientError.http(status:message:error:)` matches the existing `Networking/APIError.swift`. ✓

**Notes for the implementer:**
- Run Tasks 1–2 with `swift test` in `Packages/SlipStreamKit` (fast, no simulator). Task 3 uses XcodeBuildMCP.
- The determinism trick: `ParkingScheduler.sleep` parks ~forever, so each stream performs exactly **once** per activation; the `AsyncStream` buffers that single `yield`, so `await it.next()` never races the loop. Cancelling a driver throws `CancellationError` out of `Task.sleep`, unwinding the parked loop cleanly.
- `PollStream` is `Sendable` because its closures are `@MainActor`-isolated (global-actor closures are `Sendable`) — that's what lets the engine capture a stream into a `@MainActor` driver `Task` under Swift 6 strict concurrency.
- After merging, update `docs/TRACKER.md`: tick **F1.5**, and mark open question #5 (cadence) and the spec's background-behavior question as resolved (per-stream interval; hard-stop).

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-20-realtime-polling-engine.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
