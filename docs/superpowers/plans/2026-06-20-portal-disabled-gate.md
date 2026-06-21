# Portal-Disabled Server Gate (F2.6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the server reports `portalEnabled == false`, replace all portal UI — the pre-auth sign-in screen and the signed-in shell — with a single "Requests Portal Disabled" view.

**Architecture:** A pure wiring feature on top of existing seams. `SystemStore` (F1.4) already fetches the public `GET /api/v1/status` and exposes `portalEnabled` with an optimistic `true` default. We (1) add a thin `PortalDisabledView` in `Feature-Auth` reusing `DesignSystem.EmptyStateView`, (2) make `AuthGateView` short-circuit to it as its first branch, and (3) drive `SystemStore.refresh()` on launch + foreground from `RootView` so the gate works pre-auth. No new model or networking code.

**Tech Stack:** Swift 6, SwiftUI, iOS 26. Local SPM packages (`SlipStreamKit`, `DesignSystem`, `Feature-Auth`). XcodeBuildMCP for build/run; `swift test` for kit logic.

## Global Constraints

- iOS 26+, Swift 6, SwiftUI; force-dark theme (`.preferredColorScheme(.dark)` applied at app root).
- Feature code lives in `Packages/*`; keep `.xcodeproj` edits minimal (CLAUDE.md). Adding a source file to an SPM package needs **zero** xcodeproj edits (SPM globs `Sources/`).
- Web copy mirrored **verbatim**: title `Requests Portal Disabled`, body `The external requests portal is currently disabled. Please contact your server administrator.`
- Never inline-disable a linter rule. `make format` (apply) / `make lint` (check) must be clean.
- Build via XcodeBuildMCP (`build_sim` / `build_run_sim`) — do **not** shell out to `xcodebuild`. Kit logic via `swift test`. Simulator: **iPhone 17**.
- Scheme: `SlipStream`.

## Testing posture (read first)

The only headless-testable unit — the gate *decision*, `SystemStore.portalEnabled` propagating a server `false` — is **already covered** by `SystemStoreTests.portalDisabledPropagates` (`Packages/SlipStreamKit/Tests/SlipStreamKitTests/SystemStoreTests.swift:60`). The remaining work is SwiftUI view wiring, which this project verifies by **build + on-device**, not headless unit tests (precedent: F2.4, F1.6, F1.7 — "kit logic headless; UI verified on device"). No ViewInspector dependency exists and we will not add one. So the view tasks below are gated by a clean `build_sim` and a live check, with the existing kit test as the decision anchor.

---

### Task 1: `PortalDisabledView` + DesignSystem dependency for Feature-Auth

**Files:**
- Modify: `Packages/Feature-Auth/Package.swift` (add `DesignSystem` dependency)
- Create: `Packages/Feature-Auth/Sources/FeatureAuth/PortalDisabledView.swift`

**Interfaces:**
- Consumes: `DesignSystem.EmptyStateView(title:systemImage:description:)`, `DesignSystem.DesignTheme.background` (both already `public`).
- Produces: `public struct PortalDisabledView: View` with `public init()` — consumed by Task 2.

- [ ] **Step 1: Add the DesignSystem dependency to Feature-Auth's package**

Edit `Packages/Feature-Auth/Package.swift` so both the `dependencies` array and the target list `DesignSystem`. Final file:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "FeatureAuth",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "FeatureAuth", targets: ["FeatureAuth"])
  ],
  dependencies: [
    .package(path: "../SlipStreamKit"),
    .package(path: "../DesignSystem")
  ],
  targets: [
    .target(
      name: "FeatureAuth",
      dependencies: ["SlipStreamKit", "DesignSystem"]
    )
  ]
)
```

(No xcodeproj edit needed: `DesignSystem`'s product is already linked into the app target, so its symbols are present in the app binary; this only lets the `FeatureAuth` module `import DesignSystem` at compile time. The edge is acyclic — `DesignSystem` does not depend on `FeatureAuth`.)

- [ ] **Step 2: Create the view**

Create `Packages/Feature-Auth/Sources/FeatureAuth/PortalDisabledView.swift`:

```swift
import DesignSystem
import SwiftUI

/// Shown in place of *all* portal UI — the pre-auth sign-in screen and the
/// signed-in shell — when the server reports `portalEnabled == false` (F2.6).
/// Mirrors the web `PortalDisabledView` copy verbatim and is built on
/// `EmptyStateView`, so it inherits the force-dark visual identity. Fills the
/// screen with the theme background so it fully replaces whatever it gates.
public struct PortalDisabledView: View {
  public init() {}

  public var body: some View {
    EmptyStateView(
      title: "Requests Portal Disabled",
      systemImage: "nosign",
      description:
        "The external requests portal is currently disabled. Please contact your server administrator."
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTheme.background)
  }
}

#Preview {
  PortalDisabledView()
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 3: Format & lint the new file**

Run: `make format && make lint`
Expected: no diff left unstaged that re-breaks lint; `make lint` exits 0.

- [ ] **Step 4: Build to verify the package resolves DesignSystem and compiles**

Use XcodeBuildMCP `build_sim` (scheme `SlipStream`, simulator `iPhone 17`).
Expected: **BUILD SUCCEEDED**. (This forces Xcode to re-resolve the package graph with the new `Feature-Auth → DesignSystem` edge. If resolution fails, re-resolve packages and rebuild before proceeding.)

- [ ] **Step 5: Commit**

```bash
git add Packages/Feature-Auth/Package.swift Packages/Feature-Auth/Sources/FeatureAuth/PortalDisabledView.swift
git commit -m "feat(auth): add PortalDisabledView (F2.6)"
```

---

### Task 2: Gate `AuthGateView` on `portalEnabled`

**Files:**
- Modify: `Packages/Feature-Auth/Sources/FeatureAuth/AuthGateView.swift`

**Interfaces:**
- Consumes: `PortalDisabledView()` (Task 1); `SystemStore.portalEnabled: Bool` and `AuthStore` from `SlipStreamKit` (already imported). `SystemStore` is already injected into the environment at the app root (`SlipStreamApp.body`).
- Produces: no new public surface; behavior change only.

- [ ] **Step 1: Add the SystemStore environment and the disabled branch**

Replace the body of `Packages/Feature-Auth/Sources/FeatureAuth/AuthGateView.swift` with:

```swift
import SlipStreamKit
import SwiftUI

/// Drives the top-level auth flow. The portal-disabled gate (F2.6) is the first
/// branch: a server `portalEnabled == false` replaces *everything* — the spinner,
/// the sign-in form, and the signed-in content. Otherwise: a spinner until restore
/// finishes, then either the sign-in form (signed out) or the caller's signed-in content.
public struct AuthGateView<SignedIn: View>: View {
  @Environment(AuthStore.self) private var auth
  @Environment(SystemStore.self) private var system
  private let signedIn: () -> SignedIn

  public init(@ViewBuilder signedIn: @escaping () -> SignedIn) {
    self.signedIn = signedIn
  }

  public var body: some View {
    Group {
      if !system.portalEnabled {
        PortalDisabledView()
      } else if !auth.hasAttemptedRestore {
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
    // Keep restoring underneath the gate: if the portal flips back on (foreground
    // refresh), an already-restored session shows the shell immediately.
    .task { await auth.restore() }
  }
}
```

- [ ] **Step 2: Format & lint**

Run: `make format && make lint`
Expected: `make lint` exits 0.

- [ ] **Step 3: Confirm the decision anchor still passes**

Run: `swift test --package-path Packages/SlipStreamKit 2>&1 | tail -5`
Expected: all tests pass (includes `SystemStoreTests.portalDisabledPropagates`). This is the headless gate for the decision source.

- [ ] **Step 4: Build the app**

Use XcodeBuildMCP `build_sim` (scheme `SlipStream`, `iPhone 17`).
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 5: Commit**

```bash
git add Packages/Feature-Auth/Sources/FeatureAuth/AuthGateView.swift
git commit -m "feat(auth): gate AuthGateView on portalEnabled (F2.6)"
```

---

### Task 3: Refresh status on launch + foreground in `RootView`

**Files:**
- Modify: `App/RootView.swift`

**Interfaces:**
- Consumes: `SystemStore.refresh() async` and `system` (already `@Environment(SystemStore.self)` in `RootView`); `scenePhase`.
- Produces: no new surface; lifecycle change only. The signed-in `.task { await system.refresh() }` on `AppShellView` is **kept** (fresh-sign-in module discovery, F1.4).

- [ ] **Step 1: Fold launch+foreground refresh into the existing scenePhase handler**

In `App/RootView.swift`, replace the existing `.onChange(of: scenePhase, initial: true)` modifier with:

```swift
    .onChange(of: scenePhase, initial: true) { _, phase in
      poller.setActivity(activity(for: phase))
      // F2.6: refresh portal/module status on launch (initial: true fires once at
      // startup) and on every foreground, so the portal-disabled gate works pre-auth
      // and reacts to an admin toggle on return. The signed-in `.task` refresh above
      // is kept for fresh-sign-in module discovery (F1.4); the overlap is idempotent.
      if phase == .active {
        Task { await system.refresh() }
      }
    }
```

(Leave the `.task { await system.refresh() }` on the signed-in `AppShellView` branch unchanged. Leave the poster-cache `.onChange(of: auth.state)` and the DEBUG gallery overlay unchanged.)

- [ ] **Step 2: Format & lint**

Run: `make format && make lint`
Expected: `make lint` exits 0.

- [ ] **Step 3: Build the app**

Use XcodeBuildMCP `build_sim` (scheme `SlipStream`, `iPhone 17`).
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 4: Commit**

```bash
git add App/RootView.swift
git commit -m "feat(app): refresh system status on launch+foreground for portal gate (F2.6)"
```

---

### Task 4: Live verification, docs, and close-out

**Files:**
- Modify: `docs/tracker.md` (mark F2.6 done)
- Modify: `docs/superpowers/specs/02-authentication/portal-disabled-gate.md` (status → done)

- [ ] **Step 1: Full kit test sweep**

Run: `swift test --package-path Packages/SlipStreamKit 2>&1 | tail -5`
Expected: all green.

- [ ] **Step 2: Live — normal (enabled) path unaffected**

Use the `test-with-dev-server` skill to launch the dev server, then `build_run_sim` on **iPhone 17**. Confirm the normal sign-in → shell flow still works (the dev server defaults `requests_portal_enabled = true`, so `/status` returns `portalEnabled: true` and the gate stays open).

- [ ] **Step 3: Live — disabled path gates both screens**

Force `portalEnabled = false`, relaunch, and confirm `PortalDisabledView` ("Requests Portal Disabled") replaces the **sign-in screen** (pre-auth). Then confirm it also replaces the **signed-in shell** (if a session is already restored, the gate must win over the shell). Use whichever is least invasive:
- **Preferred:** seed the dev server's `requests_portal_enabled` setting to `false` (DB/setting store) before launch, so `/status` returns `false` with zero app-side changes. Restore it to `true` (or reset the dev DB) afterward.
- **Fallback (if seeding is impractical):** temporarily force the store disabled in a DEBUG build — e.g. a one-line local override of `SystemStore.portalEnabled`/`effectiveStatus` — launch, screenshot the gate on both the pre-auth and restored-session paths, then **revert the temporary edit** (do not commit it).

Capture a screenshot of the gate for the close-out note. (Per F2.4 precedent, the unit test is the real gate; this live check is confirmatory.)

- [ ] **Step 4: Mark the spec done**

In `docs/superpowers/specs/02-authentication/portal-disabled-gate.md`, set front-matter `status: done`, fill `plan: "2026-06-20-portal-disabled-gate"`, and add a top status blockquote summarizing the delivery (mirroring the F2.4 spec's `> **Status …**` line).

- [ ] **Step 5: Update the tracker**

In `docs/tracker.md`:
- Flip F2.6's checkbox to `[x]` and append `· ✅ **done** ([plan](superpowers/plans/2026-06-20-portal-disabled-gate.md))` with a one-line summary.
- Add a bullet under `## Plans` describing the F2.6 delivery (matching the existing per-feature entries' style).

- [ ] **Step 6: Final commit**

```bash
git add docs/tracker.md docs/superpowers/specs/02-authentication/portal-disabled-gate.md
git commit -m "docs(f2.6): mark portal-disabled gate done + tracker"
```

---

## Self-Review

**Spec coverage:**
- "Read `portalEnabled`; when `false`, render a disabled view in place of auth/app UI" → Tasks 1 (view) + 2 (gate in `AuthGateView`, which wraps both pre-auth and signed-in content). ✓
- "Make the gate work on the pre-auth login/signup screens" → Task 3 (refresh on launch/foreground so `/status` is loaded before auth) + Task 2 (gate is the first branch, evaluated before the sign-in screen). ✓
- Verbatim copy → Task 1 view literals. ✓
- Optimistic-default / no-false-lockout → inherited from existing `SystemStore` (no code change); verified by existing `refreshFailureSetsErrorAndKeepsOptimisticDefaults` test and Task 4 Step 2. ✓
- Reactivity = launch + foreground → Task 3. ✓

**Placeholder scan:** No TBD/TODO; all code blocks are complete and exact. The only deliberately open choice is Task 4 Step 3's seed-vs-fallback mechanism, with both concrete paths spelled out. ✓

**Type consistency:** `PortalDisabledView()` (Task 1) is the exact symbol referenced in Task 2. `system.portalEnabled` / `system.refresh()` match `SystemStore`'s existing public API (verified in source). `EmptyStateView(title:systemImage:description:)` and `DesignTheme.background` match `DesignSystem` source. ✓
