# Design System & Image Loading (F1.7) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `DesignSystem` SwiftUI package — Nuke-backed cached poster loading, an adaptive poster grid, a persisted poster-size preference, loading skeletons, and empty/error states — that the Discovery, Request, and Detail screens (Epics 03–05) will all reuse, plus the pure poster-sizing logic those views depend on (added to `SlipStreamKit` so it is unit-tested headlessly).

**Architecture:** The pure, testable poster-sizing logic (grid metrics + a persisted, observable poster-size preference) lands in **`SlipStreamKit`**, next to `AuthStore`, because it is platform-agnostic Foundation/Observation code with no SwiftUI — so it runs under the existing headless `swift test` loop on the Mac host. The SwiftUI components and the Nuke image stack land in a **new iOS-only `DesignSystem` package** (mirroring how `Feature-Auth` is structured), which depends on `SlipStreamKit` for the metrics/preference and on **Nuke** (`NukeUI.LazyImage` + `Nuke.ImagePipeline`) for cached image loading. A DEBUG-only `DesignSystemGalleryView` is surfaced as a second tab in `RootView` so every component is verifiable on the simulator without signing in. Poster artwork caches are cleared on sign-out (shared family device).

**Tech Stack:** Swift 6.2 (strict concurrency), SwiftUI, `@Observable` (Observation), Swift Package Manager (local path packages + one remote dependency: Nuke), Swift Testing, Nuke 12 (`NukeUI`, `Nuke`), XcodeBuildMCP for simulator build/test/screenshot.

## Global Constraints

These are copied verbatim from the foundation plan's constraints and the F1.7 spec; every task below implicitly inherits them.

- **Language/mode:** Swift 6.2, strict concurrency (`// swift-tools-version: 6.2`). Every type crossing a concurrency boundary is `Sendable`; UI/state types are `@MainActor`.
- **Deployment target:** iOS/iPadOS **26.0** minimum. `SlipStreamKit` additionally supports **macOS 14** *only* so its pure-logic tests run via `swift test`. The new `DesignSystem` package is **iOS-only** (`.iOS(.v26)`), like `Feature-Auth`.
- **Bundle id:** `dev.jatassi.slipstream`. **Signing:** free Apple Personal Team. No paid entitlements.
- **One adaptive SwiftUI layer** serves iPhone, iPad, and Mac (Designed-for-iPad). Use size classes; do not branch on platform unless an API is truly unavailable.
- **Contract / source of truth (web portal):** `~/Git/SlipStream/web/src`. The values mirrored here come from `routes/requests/library.tsx` (`PosterSizeSlider`, `GridSkeleton`), `stores/ui.ts` (`posterSize`), `routes/requests/search-loading-skeleton.tsx`, and `components/data/empty-state.tsx`. Do not invent values — the exact numbers are pinned in Task 1.
- **Poster facts (from the web `posterSize` UI store):** min-item-width range **100–250**, default **150**, step **25 on compact (phone) / 10 on regular (iPad/Mac)**, persisted, **shared across all media surfaces** (one global preference, not per-screen). Grid is `repeat(auto-fill, minmax(posterSize, 1fr))` → SwiftUI `GridItem(.adaptive(minimum: posterSize))`.
- **Poster styling (from the web poster card):** aspect ratio **2:3** (portrait), corner radius **8pt** (Tailwind `rounded-lg` = 0.5rem), muted-fill **pulse** placeholder while loading, film/tv SF-Symbol fallback when the image fails. Library grid gap **16pt** (`gap-4`); search skeleton gap **12pt** (`gap-3`).
- **Image URLs are NOT built here.** The portal's `PortalMovieSearchResult.posterUrl` / `PortalSeriesSearchResult.posterUrl` are already-resolved `string | null` URLs from the server. `PosterImage` consumes a `URL?`. The local-artwork/TMDB fallback URL chain (`/api/v1/metadata/artwork/...`, `https://image.tmdb.org/t/p/...`) is a data-layer concern owned by Epic 03 — out of scope for F1.7.
- **Build/test:** use XcodeBuildMCP, never raw `xcodebuild`. Scheme `SlipStream`; simulators `iPhone 17`, `iPad Pro 13-inch (M4)`. Headless package logic uses `cd Packages/SlipStreamKit && swift test`.
- **Commits:** frequent, one per task minimum. Solo repo — commit directly to `main`'s working tree (the executing skill manages branching/worktree).

### Resolved open questions (from the spec)

- **Port the poster-size control to phone?** → **Yes.** `PosterSizeSlider` renders on every size class; the step is mobile-aware (compact = 25, regular = 10), mirroring the web's `isMobile ? 25 : 10`.
- **Share the poster-size preference across surfaces, or per-screen?** → **Shared/global.** One `PosterSizePreference` (persisted under `slipstream.posterSize`) is injected via the SwiftUI environment and reused by every media surface, mirroring the web's single shared UI store.

---

## File structure (this plan)

```
SlipStream-iOS/
  App/
    SlipStreamApp.swift                 # MODIFY: configure Nuke pipeline at launch (Task 3)
    RootView.swift                      # MODIFY: DEBUG gallery tab (Task 3)
    SignedInPlaceholderView.swift       # MODIFY: clear poster cache on sign-out (Task 8)
  Packages/
    SlipStreamKit/
      Sources/SlipStreamKit/Design/
        PosterGridMetrics.swift         # pure metrics: range/default/step/clamp (Task 1)
        PosterSizeStore.swift           # PosterSizeStoring + UserDefaultsPosterSizeStore (Task 2)
        PosterSizePreference.swift      # @MainActor @Observable preference (Task 2)
      Tests/SlipStreamKitTests/
        PosterGridMetricsTests.swift     # (Task 1)
        PosterSizeFakes.swift            # FakePosterSizeStore (Task 2)
        PosterSizePreferenceTests.swift  # (Task 2)
    DesignSystem/                        # NEW iOS-only package (Task 3)
      Package.swift                      # iOS 26; deps: ../SlipStreamKit + Nuke (Task 3)
      Sources/DesignSystem/
        PosterImagePipeline.swift        # Nuke pipeline config + clearImageCache (Task 3)
        DesignSystemGalleryView.swift    # DEBUG component catalog, section stubs (Task 3)
        Pulse.swift                      # `.pulsing()` shimmer modifier (Task 4)
        PosterImage.swift                # PosterKind + Nuke-backed poster view (Task 4)
        PosterGrid.swift                 # adaptive LazyVGrid container (Task 5)
        PosterSizeSlider.swift           # size control bound to the preference (Task 5)
        Skeletons.swift                  # PosterCellSkeleton/GridSkeleton/SearchSkeleton (Task 6)
        StateViews.swift                 # EmptyStateView + ErrorStateView (Task 7)
```

**External dependency added:** Nuke (`https://github.com/kean/Nuke`), products `NukeUI` + `Nuke`. First and only third-party dependency in the project. It is declared by the `DesignSystem` package and reaches the app target transitively.

---

### Task 1: Poster grid metrics (pure, headless TDD)

The pure sizing constants and helpers that both the preference (clamping) and the SwiftUI grid/slider consume. No SwiftUI, no UserDefaults — just `CGFloat` math, so it runs under `swift test` on the Mac host. Mirrors the web `posterSize` range and the slider's mobile-aware step.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterGridMetrics.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterGridMetricsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum PosterGridMetrics` with static `CGFloat` constants `minSize = 100`, `maxSize = 250`, `defaultSize = 150`, `compactStep = 25`, `regularStep = 10`, `spacing = 16`.
  - `static func clamp(_ size: CGFloat) -> CGFloat` (clamps into `minSize...maxSize`).
  - `static func step(isCompact: Bool) -> CGFloat` (returns `compactStep` / `regularStep`).

- [ ] **Step 1: Write the failing metrics test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterGridMetricsTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import SlipStreamKit

@Suite struct PosterGridMetricsTests {
    @Test func constantsMatchTheWebPortal() {
        #expect(PosterGridMetrics.minSize == 100)
        #expect(PosterGridMetrics.maxSize == 250)
        #expect(PosterGridMetrics.defaultSize == 150)
        #expect(PosterGridMetrics.spacing == 16)
    }

    @Test func clampPassesValuesWithinRange() {
        #expect(PosterGridMetrics.clamp(150) == 150)
        #expect(PosterGridMetrics.clamp(100) == 100)
        #expect(PosterGridMetrics.clamp(250) == 250)
    }

    @Test func clampFloorsBelowMinimum() {
        #expect(PosterGridMetrics.clamp(40) == 100)
    }

    @Test func clampCeilsAboveMaximum() {
        #expect(PosterGridMetrics.clamp(900) == 250)
    }

    @Test func stepIsMobileAware() {
        #expect(PosterGridMetrics.step(isCompact: true) == 25)
        #expect(PosterGridMetrics.step(isCompact: false) == 10)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'PosterGridMetrics' in scope`.

- [ ] **Step 3: Write the metrics**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterGridMetrics.swift`:

```swift
import CoreGraphics

/// Pure poster-grid sizing, mirroring the web portal's `posterSize` UI store
/// (`web/src/stores/ui.ts`) and the `PosterSizeSlider` in
/// `web/src/routes/requests/library.tsx`. `size` is the minimum item width in
/// points, fed to `GridItem(.adaptive(minimum:))` — the SwiftUI equivalent of
/// the web's `repeat(auto-fill, minmax(posterSize, 1fr))`.
public enum PosterGridMetrics {
    /// Smallest allowed minimum item width (web slider `min`).
    public static let minSize: CGFloat = 100
    /// Largest allowed minimum item width (web slider `max`).
    public static let maxSize: CGFloat = 250
    /// Default minimum item width (web store default).
    public static let defaultSize: CGFloat = 150
    /// Slider step on compact width / phones (`isMobile ? 25`).
    public static let compactStep: CGFloat = 25
    /// Slider step on regular width / iPad + Mac (`: 10`).
    public static let regularStep: CGFloat = 10
    /// Grid gutter (web `gap-4` = 1rem).
    public static let spacing: CGFloat = 16

    /// Clamp a requested size into the supported range.
    public static func clamp(_ size: CGFloat) -> CGFloat {
        min(max(size, minSize), maxSize)
    }

    /// The poster-size slider step for the current width class.
    public static func step(isCompact: Bool) -> CGFloat {
        isCompact ? compactStep : regularStep
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (existing 11 + 5 new = 16).

- [ ] **Step 5: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterGridMetrics.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterGridMetricsTests.swift
git commit -m "feat(kit): add PosterGridMetrics mirroring web posterSize store"
```

---

### Task 2: Poster-size preference store (persisted, observable, headless TDD)

A persisted, observable poster-size preference — the iOS equivalent of the web's shared, persisted `posterSize` UI store. A `PosterSizeStoring` seam keeps it testable with a fake; the real `UserDefaultsPosterSizeStore` persists to `UserDefaults` (the iOS analogue of the web's `localStorage` `slipstream-ui` key). `PosterSizePreference` is `@MainActor @Observable` (same pattern as `AuthStore`) so SwiftUI views observe size changes.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterSizeStore.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterSizePreference.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterSizeFakes.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterSizePreferenceTests.swift`

**Interfaces:**
- Consumes: `PosterGridMetrics` (Task 1).
- Produces:
  - `protocol PosterSizeStoring: Sendable { func loadPosterSize() -> CGFloat?; func savePosterSize(_ size: CGFloat) }`
  - `final class UserDefaultsPosterSizeStore: PosterSizeStoring` with `init(defaults: UserDefaults = .standard)`, key `"slipstream.posterSize"`.
  - `@MainActor @Observable final class PosterSizePreference` with `init(store: PosterSizeStoring)`, `var size: CGFloat` (`private(set)`), `func setSize(_ newSize: CGFloat)` (clamps via `PosterGridMetrics.clamp` and persists).

- [ ] **Step 1: Write the failing preference tests**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterSizeFakes.swift`:

```swift
import CoreGraphics
@testable import SlipStreamKit

final class FakePosterSizeStore: PosterSizeStoring, @unchecked Sendable {
    var stored: CGFloat?
    private(set) var saveCount = 0
    init(stored: CGFloat? = nil) { self.stored = stored }
    func loadPosterSize() -> CGFloat? { stored }
    func savePosterSize(_ size: CGFloat) { stored = size; saveCount += 1 }
}
```

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterSizePreferenceTests.swift`:

```swift
import Testing
import Foundation
import CoreGraphics
@testable import SlipStreamKit

@MainActor
@Suite struct PosterSizePreferenceTests {
    @Test func usesDefaultWhenStoreEmpty() {
        let pref = PosterSizePreference(store: FakePosterSizeStore(stored: nil))
        #expect(pref.size == PosterGridMetrics.defaultSize)
    }

    @Test func loadsPersistedValueClamped() {
        let pref = PosterSizePreference(store: FakePosterSizeStore(stored: 999))
        #expect(pref.size == PosterGridMetrics.maxSize)
    }

    @Test func setSizeClampsWithinRangeAndPersists() {
        let store = FakePosterSizeStore()
        let pref = PosterSizePreference(store: store)
        pref.setSize(220)
        #expect(pref.size == 220)
        #expect(store.stored == 220)
        #expect(store.saveCount == 1)
    }

    @Test func setSizeAboveMaxClampsToMaxAndPersistsClamped() {
        let store = FakePosterSizeStore()
        let pref = PosterSizePreference(store: store)
        pref.setSize(400)
        #expect(pref.size == PosterGridMetrics.maxSize)
        #expect(store.stored == PosterGridMetrics.maxSize)
    }

    @Test func userDefaultsStoreRoundTrips() {
        let suite = "test.slipstream.posterSize"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = UserDefaultsPosterSizeStore(defaults: defaults)
        #expect(store.loadPosterSize() == nil)
        store.savePosterSize(180)
        #expect(store.loadPosterSize() == 180)
        defaults.removePersistentDomain(forName: suite)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'PosterSizePreference' in scope`.

- [ ] **Step 3: Write the store and preference**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterSizeStore.swift`:

```swift
import Foundation
import CoreGraphics

/// Persistence seam for the poster-size preference. The iOS analogue of the
/// web's persisted `posterSize` field in the `slipstream-ui` localStorage store.
public protocol PosterSizeStoring: Sendable {
    func loadPosterSize() -> CGFloat?
    func savePosterSize(_ size: CGFloat)
}

/// Real `UserDefaults`-backed implementation. Poster size is a non-secret UI
/// preference, so `UserDefaults` (not the Keychain) is the right home.
public final class UserDefaultsPosterSizeStore: PosterSizeStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "slipstream.posterSize"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadPosterSize() -> CGFloat? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return CGFloat(defaults.double(forKey: key))
    }

    public func savePosterSize(_ size: CGFloat) {
        defaults.set(Double(size), forKey: key)
    }
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterSizePreference.swift`:

```swift
import Foundation
import Observation
import CoreGraphics

/// The shared, observable poster-size preference. One instance is injected via
/// the SwiftUI environment and reused across every media surface, mirroring the
/// web's single shared UI store. `size` is the grid's minimum item width.
@MainActor
@Observable
public final class PosterSizePreference {
    public private(set) var size: CGFloat
    private let store: PosterSizeStoring

    public init(store: PosterSizeStoring) {
        self.store = store
        self.size = PosterGridMetrics.clamp(store.loadPosterSize() ?? PosterGridMetrics.defaultSize)
    }

    /// Clamp into the supported range, update, and persist.
    public func setSize(_ newSize: CGFloat) {
        let clamped = PosterGridMetrics.clamp(newSize)
        size = clamped
        store.savePosterSize(clamped)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (16 + 5 new = 21).

- [ ] **Step 5: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterSizeStore.swift \
        Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterSizePreference.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterSizeFakes.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterSizePreferenceTests.swift
git commit -m "feat(kit): add persisted, observable PosterSizePreference"
```

---

### Task 3: DesignSystem package + Nuke pipeline + DEBUG gallery harness

Stand up the new iOS-only `DesignSystem` package, add Nuke, configure the shared image pipeline, and wire a DEBUG-only gallery tab into the app so every later component is verifiable on the simulator without signing in. Deliverable: the app builds and launches on the simulator with a working (empty) "Gallery" tab alongside the normal auth flow.

**Files:**
- Create: `Packages/DesignSystem/Package.swift`
- Create: `Packages/DesignSystem/Sources/DesignSystem/PosterImagePipeline.swift`
- Create: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift`
- Modify: `App/SlipStreamApp.swift` (configure pipeline at launch)
- Modify: `App/RootView.swift` (DEBUG gallery tab)
- Create (Xcode GUI): link `DesignSystem` into the `SlipStream` app target

**Interfaces:**
- Consumes: `PosterSizePreference`, `UserDefaultsPosterSizeStore` (Task 2).
- Produces:
  - `enum PosterImagePipeline { static func configure(); static func clearImageCache() }`
  - `struct DesignSystemGalleryView: View` with `init()` and four `@ViewBuilder` section properties (`posterImageSection`, `posterGridSection`, `skeletonSection`, `statesSection`) — stubbed to `EmptyView()` here, filled by Tasks 4–7.

- [ ] **Step 1: Create the package manifest**

Create `Packages/DesignSystem/Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    dependencies: [
        .package(path: "../SlipStreamKit"),
        .package(url: "https://github.com/kean/Nuke", from: "12.8.0"),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [
                "SlipStreamKit",
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "Nuke", package: "Nuke"),
            ]
        ),
    ]
)
```

- [ ] **Step 2: Verify Nuke resolves**

Run: `cd Packages/DesignSystem && swift package resolve`
Expected: `Computing version for https://github.com/kean/Nuke` … and the package resolves to a `12.x` version, writing `Packages/DesignSystem/Package.resolved`. (Resolution reads the manifest only — it does not compile, so the iOS-only platform is fine on the Mac host.) If the toolchain rejects `12.8.0`, raise the lower bound to the latest tag `swift package resolve` prints; the `LazyImage` / `ImagePipeline.shared` / `cache.removeAll()` APIs used in this plan are unchanged across Nuke 12–13.

- [ ] **Step 3: Write the Nuke image pipeline**

Create `Packages/DesignSystem/Sources/DesignSystem/PosterImagePipeline.swift`:

```swift
import Nuke

/// The shared Nuke pipeline for poster/backdrop artwork. Adds an on-disk
/// `DataCache` on top of Nuke's in-memory cache for high poster throughput, and
/// exposes a cache-clear used on sign-out (shared family device).
public enum PosterImagePipeline {
    /// Install the poster pipeline as `ImagePipeline.shared`. Call once at launch,
    /// before any `LazyImage` renders.
    public static func configure() {
        let pipeline = ImagePipeline {
            $0.dataCache = try? DataCache(name: "dev.jatassi.slipstream.posters")
            $0.dataCachePolicy = .automatic
        }
        ImagePipeline.shared = pipeline
    }

    /// Drop all cached artwork (memory + disk). Called on sign-out.
    public static func clearImageCache() {
        ImagePipeline.shared.cache.removeAll()
    }
}
```

- [ ] **Step 4: Write the gallery harness (stub sections)**

Create `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// A DEBUG-only living catalog of DesignSystem components. Surfaced as a tab in
/// `RootView` so each component can be verified on the simulator without signing
/// in. Tasks 4–7 replace the `EmptyView()` section stubs below with real content.
public struct DesignSystemGalleryView: View {
    @State private var posterSize = PosterSizePreference(store: UserDefaultsPosterSizeStore())

    public init() {}

    public var body: some View {
        List {
            posterImageSection
            posterGridSection
            skeletonSection
            statesSection
        }
        .navigationTitle("Design System")
    }

    @ViewBuilder private var posterImageSection: some View { EmptyView() }
    @ViewBuilder private var posterGridSection: some View { EmptyView() }
    @ViewBuilder private var skeletonSection: some View { EmptyView() }
    @ViewBuilder private var statesSection: some View { EmptyView() }
}
```

- [ ] **Step 5: Link DesignSystem into the app (Xcode GUI)**

In Xcode: select the `SlipStream` project → `SlipStream` target → General → Frameworks, Libraries, and Embedded Content (or File → Add Package Dependencies → Add Local…) → add `Packages/DesignSystem` → add the `DesignSystem` library product to the `SlipStream` target. Xcode resolves Nuke transitively (File → Packages → Resolve Package Versions if it does not auto-resolve). Keep `.xcodeproj` edits to this single link, per CLAUDE.md.

- [ ] **Step 6: Configure the pipeline at launch**

Replace `App/SlipStreamApp.swift` with:

```swift
import SwiftUI
import SlipStreamKit
import DesignSystem

@main
struct SlipStreamApp: App {
    @State private var auth = AuthStore(
        makeAuthAPI: { url in PortalAPIClient(baseURL: url) },
        tokenStore: KeychainTokenStore(),
        serverConfig: UserDefaultsServerConfigStore()
    )

    init() {
        PosterImagePipeline.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
    }
}
```

- [ ] **Step 7: Add the DEBUG gallery tab**

Replace `App/RootView.swift` with:

```swift
import SwiftUI
import FeatureAuth
import DesignSystem

struct RootView: View {
    var body: some View {
        #if DEBUG
        TabView {
            AuthGateView {
                SignedInPlaceholderView()
            }
            .tabItem { Label("App", systemImage: "play.circle") }

            NavigationStack {
                DesignSystemGalleryView()
            }
            .tabItem { Label("Gallery", systemImage: "swatchpalette") }
        }
        #else
        AuthGateView {
            SignedInPlaceholderView()
        }
        #endif
    }
}
```

- [ ] **Step 8: Build and launch on the simulator**

```
mcp__xcodebuildmcp__build_run_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED`, the app launches showing a tab bar with "App" and "Gallery". Tap "Gallery" → an empty "Design System" list (no rows yet — sections are stubs). If Nuke fails to link, re-run File → Packages → Resolve Package Versions in Xcode.

- [ ] **Step 9: Commit**

```bash
git add Packages/DesignSystem App/SlipStreamApp.swift App/RootView.swift SlipStream.xcodeproj
git commit -m "feat(ds): scaffold DesignSystem package, Nuke pipeline, DEBUG gallery tab"
```

---

### Task 4: PosterImage + pulse placeholder

The Nuke-backed poster view: a 2:3 rounded cell that shows a muted pulse while loading, the image scaled-to-fill when loaded, and a film/tv SF-Symbol fallback on failure — mirroring the web `PosterImage` component and its `FallbackIcon`. Also introduces the reusable `.pulsing()` shimmer used by the skeletons in Task 6.

**Files:**
- Create: `Packages/DesignSystem/Sources/DesignSystem/Pulse.swift`
- Create: `Packages/DesignSystem/Sources/DesignSystem/PosterImage.swift`
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift` (fill `posterImageSection`)

**Interfaces:**
- Consumes: `NukeUI.LazyImage`.
- Produces:
  - `func pulsing() -> some View` (internal `View` extension) — repeating opacity pulse, the iOS analogue of Tailwind `animate-pulse`.
  - `enum PosterKind: Sendable { case movie; case series }`.
  - `struct PosterImage: View` with `init(url: URL?, kind: PosterKind, cornerRadius: CGFloat = 8)`.

- [ ] **Step 1: Write the pulse modifier**

Create `Packages/DesignSystem/Sources/DesignSystem/Pulse.swift`:

```swift
import SwiftUI

/// Repeating opacity pulse — the iOS analogue of Tailwind's `animate-pulse`,
/// used for the muted placeholders the web renders with `bg-muted animate-pulse`.
private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.35 : 0.85)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

extension View {
    /// Apply the standard loading-placeholder pulse.
    func pulsing() -> some View { modifier(PulseModifier()) }
}
```

- [ ] **Step 2: Write the poster view**

Create `Packages/DesignSystem/Sources/DesignSystem/PosterImage.swift`:

```swift
import SwiftUI
import NukeUI

/// Whether a poster represents a movie or a series — selects the fallback icon,
/// mirroring the web `FallbackIcon` (`Film` vs `Tv`).
public enum PosterKind: Sendable {
    case movie
    case series

    var fallbackSymbol: String {
        switch self {
        case .movie: "film"
        case .series: "tv"
        }
    }
}

/// A cached poster image in the portal's 2:3 portrait format with an 8pt corner
/// radius. Shows a muted pulse while loading, scales the image to fill on
/// success, and falls back to a film/tv glyph on failure. The `url` is the
/// server-resolved `posterUrl`; building artwork URLs is Epic 03's concern.
public struct PosterImage: View {
    private let url: URL?
    private let kind: PosterKind
    private let cornerRadius: CGFloat

    public init(url: URL?, kind: PosterKind, cornerRadius: CGFloat = 8) {
        self.url = url
        self.kind = kind
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else if state.error != nil {
                        fallback
                    } else {
                        Rectangle()
                            .fill(Color(.secondarySystemFill))
                            .pulsing()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var fallback: some View {
        ZStack {
            Color(.secondarySystemFill)
            Image(systemName: kind.fallbackSymbol)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("PosterImage") {
    HStack(spacing: 16) {
        PosterImage(url: nil, kind: .movie)
        PosterImage(url: nil, kind: .series)
    }
    .frame(height: 240)
    .padding()
}
```

- [ ] **Step 3: Add the gallery section**

In `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift`, replace the stub line:

```swift
    @ViewBuilder private var posterImageSection: some View { EmptyView() }
```

with:

```swift
    @ViewBuilder private var posterImageSection: some View {
        Section("PosterImage") {
            HStack(spacing: 16) {
                PosterImage(url: URL(string: "https://image.tmdb.org/t/p/w342/8IB2e4r4oVhHnANbnm7O3Tj6tF8.jpg"), kind: .movie)
                PosterImage(url: nil, kind: .movie)
                PosterImage(url: nil, kind: .series)
            }
            .frame(height: 180)
        }
    }
```

- [ ] **Step 4: Build to verify it compiles and the preview is valid**

```
mcp__xcodebuildmcp__build_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED`. (The middle/right cells render the film/tv fallback offline; the left cell loads a real poster when the simulator has network. Full visual screenshot happens in Task 8.)

- [ ] **Step 5: Commit**

```bash
git add Packages/DesignSystem/Sources/DesignSystem/Pulse.swift \
        Packages/DesignSystem/Sources/DesignSystem/PosterImage.swift \
        Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift
git commit -m "feat(ds): add Nuke-backed PosterImage with pulse + fallback"
```

---

### Task 5: Adaptive PosterGrid + PosterSizeSlider

The reusable adaptive poster grid (SwiftUI `GridItem(.adaptive(minimum:))`, the equivalent of the web's `repeat(auto-fill, minmax(posterSize, 1fr))`) and the poster-size control bound to the shared `PosterSizePreference`, with the mobile-aware step.

**Files:**
- Create: `Packages/DesignSystem/Sources/DesignSystem/PosterGrid.swift`
- Create: `Packages/DesignSystem/Sources/DesignSystem/PosterSizeSlider.swift`
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift` (fill `posterGridSection`)

**Interfaces:**
- Consumes: `PosterGridMetrics`, `PosterSizePreference` (Tasks 1–2); `PosterImage` (Task 4).
- Produces:
  - `struct PosterGrid<Item: Identifiable, Cell: View>: View` with `init(items: [Item], minItemWidth: CGFloat, spacing: CGFloat = PosterGridMetrics.spacing, @ViewBuilder cell: @escaping (Item) -> Cell)`. Renders a bare `LazyVGrid` (caller supplies the enclosing `ScrollView`).
  - `struct PosterSizeSlider: View` with `init(preference: PosterSizePreference)`.

- [ ] **Step 1: Write the adaptive grid**

Create `Packages/DesignSystem/Sources/DesignSystem/PosterGrid.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// An adaptive poster grid: as many columns of at least `minItemWidth` as fit,
/// each growing to fill the row — the SwiftUI equivalent of the web's
/// `grid-template-columns: repeat(auto-fill, minmax(posterSize, 1fr))`. Renders a
/// bare `LazyVGrid`; wrap it in a `ScrollView` at the call site.
public struct PosterGrid<Item: Identifiable, Cell: View>: View {
    private let items: [Item]
    private let minItemWidth: CGFloat
    private let spacing: CGFloat
    private let cell: (Item) -> Cell

    public init(
        items: [Item],
        minItemWidth: CGFloat,
        spacing: CGFloat = PosterGridMetrics.spacing,
        @ViewBuilder cell: @escaping (Item) -> Cell
    ) {
        self.items = items
        self.minItemWidth = minItemWidth
        self.spacing = spacing
        self.cell = cell
    }

    public var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minItemWidth), spacing: spacing)],
            spacing: spacing
        ) {
            ForEach(items) { item in
                cell(item)
            }
        }
    }
}
```

- [ ] **Step 2: Write the poster-size slider**

Create `Packages/DesignSystem/Sources/DesignSystem/PosterSizeSlider.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// The poster-size control, bound to the shared `PosterSizePreference`. Mirrors
/// the web `PosterSizeSlider`: range 100–250 with a mobile-aware step (25 on
/// compact width, 10 on regular). Writes go through `setSize`, which clamps and
/// persists.
public struct PosterSizeSlider: View {
    private let preference: PosterSizePreference
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(preference: PosterSizePreference) {
        self.preference = preference
    }

    public var body: some View {
        let step = PosterGridMetrics.step(isCompact: horizontalSizeClass == .compact)
        HStack(spacing: 8) {
            Text("Size")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { preference.size },
                    set: { preference.setSize($0) }
                ),
                in: PosterGridMetrics.minSize...PosterGridMetrics.maxSize,
                step: step
            )
            .frame(maxWidth: 160)
        }
    }
}
```

- [ ] **Step 3: Add the gallery section**

In `DesignSystemGalleryView.swift`, replace:

```swift
    @ViewBuilder private var posterGridSection: some View { EmptyView() }
```

with:

```swift
    @ViewBuilder private var posterGridSection: some View {
        Section("PosterGrid + PosterSizeSlider") {
            PosterSizeSlider(preference: posterSize)
            PosterGrid(items: GalleryPoster.samples, minItemWidth: posterSize.size) { poster in
                PosterImage(url: nil, kind: poster.kind)
            }
        }
    }
```

Then add this sample type at the end of `DesignSystemGalleryView.swift` (after the `}` that closes `struct DesignSystemGalleryView`):

```swift
/// Throwaway sample data for the gallery's grid section.
private struct GalleryPoster: Identifiable {
    let id: Int
    let kind: PosterKind

    static let samples: [GalleryPoster] = (0..<8).map {
        GalleryPoster(id: $0, kind: $0.isMultiple(of: 2) ? .movie : .series)
    }
}
```

- [ ] **Step 4: Build to verify**

```
mcp__xcodebuildmcp__build_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED`. Dragging the slider in the Gallery tab reflows the grid (verified visually in Task 8).

- [ ] **Step 5: Commit**

```bash
git add Packages/DesignSystem/Sources/DesignSystem/PosterGrid.swift \
        Packages/DesignSystem/Sources/DesignSystem/PosterSizeSlider.swift \
        Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift
git commit -m "feat(ds): add adaptive PosterGrid and PosterSizeSlider"
```

---

### Task 6: Loading skeletons

The loading placeholders, mirroring the web `GridSkeleton` (12 muted 2:3 pulse cells in the poster grid) and `SearchLoadingSkeleton` (12 denser cells). Built from the `PosterCellSkeleton` primitive and the `.pulsing()` modifier from Task 4.

**Files:**
- Create: `Packages/DesignSystem/Sources/DesignSystem/Skeletons.swift`
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift` (fill `skeletonSection`)

**Interfaces:**
- Consumes: `PosterGridMetrics` (Task 1); `.pulsing()` (Task 4).
- Produces:
  - `struct PosterCellSkeleton: View` with `init(cornerRadius: CGFloat = 8)` — one muted 2:3 pulse cell.
  - `struct PosterGridSkeleton: View` with `init(count: Int = 12, minItemWidth: CGFloat = PosterGridMetrics.defaultSize, spacing: CGFloat = PosterGridMetrics.spacing)`.
  - `struct SearchLoadingSkeleton: View` with `init(count: Int = 12)` — denser grid (`minItemWidth = 100`, `spacing = 12`).

- [ ] **Step 1: Write the skeletons**

Create `Packages/DesignSystem/Sources/DesignSystem/Skeletons.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// One muted, pulsing 2:3 poster placeholder — the web's
/// `bg-muted aspect-[2/3] animate-pulse rounded-lg` cell.
public struct PosterCellSkeleton: View {
    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemFill))
                    .pulsing()
            }
    }
}

/// A full grid of poster placeholders, mirroring the web `GridSkeleton`
/// (12 cells, adaptive columns, `gap-4`).
public struct PosterGridSkeleton: View {
    private let count: Int
    private let minItemWidth: CGFloat
    private let spacing: CGFloat

    public init(
        count: Int = 12,
        minItemWidth: CGFloat = PosterGridMetrics.defaultSize,
        spacing: CGFloat = PosterGridMetrics.spacing
    ) {
        self.count = count
        self.minItemWidth = minItemWidth
        self.spacing = spacing
    }

    public var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minItemWidth), spacing: spacing)],
            spacing: spacing
        ) {
            ForEach(0..<count, id: \.self) { _ in
                PosterCellSkeleton()
            }
        }
    }
}

/// The denser placeholder grid for search results, mirroring the web
/// `SearchLoadingSkeleton` (12 cells, smaller posters, `gap-3`).
public struct SearchLoadingSkeleton: View {
    private let count: Int

    public init(count: Int = 12) {
        self.count = count
    }

    public var body: some View {
        PosterGridSkeleton(count: count, minItemWidth: 100, spacing: 12)
    }
}

#Preview("PosterGridSkeleton") {
    ScrollView { PosterGridSkeleton().padding() }
}
```

- [ ] **Step 2: Add the gallery section**

In `DesignSystemGalleryView.swift`, replace:

```swift
    @ViewBuilder private var skeletonSection: some View { EmptyView() }
```

with:

```swift
    @ViewBuilder private var skeletonSection: some View {
        Section("Skeletons") {
            PosterGridSkeleton(count: 6)
            SearchLoadingSkeleton(count: 6)
        }
    }
```

- [ ] **Step 3: Build to verify**

```
mcp__xcodebuildmcp__build_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Packages/DesignSystem/Sources/DesignSystem/Skeletons.swift \
        Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift
git commit -m "feat(ds): add poster grid + search loading skeletons"
```

---

### Task 7: Empty & error states

Reusable empty- and error-state components, mirroring the web `EmptyState` (icon + title + optional description + optional action) and `SearchErrorState` (icon + message + Retry). Implemented as thin wrappers over the modern `ContentUnavailableView`.

**Files:**
- Create: `Packages/DesignSystem/Sources/DesignSystem/StateViews.swift`
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift` (fill `statesSection`)

**Interfaces:**
- Consumes: SwiftUI `ContentUnavailableView`.
- Produces:
  - `struct EmptyStateView: View` with `init(title: String, systemImage: String, description: String? = nil)`.
  - `struct ErrorStateView: View` with `init(message: String, retry: @escaping () -> Void)`.

- [ ] **Step 1: Write the state views**

Create `Packages/DesignSystem/Sources/DesignSystem/StateViews.swift`:

```swift
import SwiftUI

/// A centered empty state — icon + title + optional description. Mirrors the web
/// `EmptyState` component. Built on `ContentUnavailableView` for the modern idiom.
public struct EmptyStateView: View {
    private let title: String
    private let systemImage: String
    private let description: String?

    public init(title: String, systemImage: String, description: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let description {
                Text(description)
            }
        }
    }
}

/// A centered error state with a Retry action, mirroring the web `SearchErrorState`.
public struct ErrorStateView: View {
    private let message: String
    private let retry: () -> Void

    public init(message: String, retry: @escaping () -> Void) {
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("States") {
    VStack {
        EmptyStateView(
            title: "No movies available",
            systemImage: "film",
            description: "Movies with files will appear here"
        )
        ErrorStateView(message: "Failed to search") {}
    }
}
```

- [ ] **Step 2: Add the gallery section**

In `DesignSystemGalleryView.swift`, replace:

```swift
    @ViewBuilder private var statesSection: some View { EmptyView() }
```

with:

```swift
    @ViewBuilder private var statesSection: some View {
        Section("Empty / Error states") {
            EmptyStateView(
                title: "No movies available",
                systemImage: "film",
                description: "Movies with files will appear here"
            )
            ErrorStateView(message: "Failed to search") {}
        }
    }
```

- [ ] **Step 3: Build to verify**

```
mcp__xcodebuildmcp__build_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Packages/DesignSystem/Sources/DesignSystem/StateViews.swift \
        Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift
git commit -m "feat(ds): add empty and error state views"
```

---

### Task 8: Sign-out cache clear + end-to-end visual verification

Wire the poster cache-clear into the sign-out path (shared family device — the spec's "consider clearing the Nuke cache on sign-out"), then verify the whole gallery renders on the simulator with a screenshot.

**Files:**
- Modify: `App/SignedInPlaceholderView.swift`

**Interfaces:**
- Consumes: `PosterImagePipeline` (Task 3); existing `AuthStore` (unchanged).
- Produces: the verified DesignSystem, integrated into the app.

- [ ] **Step 1: Clear the poster cache on sign-out**

In `App/SignedInPlaceholderView.swift`, add the `DesignSystem` import and clear the cache alongside sign-out. Replace:

```swift
import SwiftUI
import SlipStreamKit
```

with:

```swift
import SwiftUI
import SlipStreamKit
import DesignSystem
```

and replace:

```swift
            Button("Sign Out") {
                Task { await auth.signOut() }
            }
```

with:

```swift
            Button("Sign Out") {
                Task {
                    await auth.signOut()
                    PosterImagePipeline.clearImageCache()
                }
            }
```

> Note for future work: when F2.4 (401 auto-logout) lands its own auto sign-out path, call `PosterImagePipeline.clearImageCache()` there too. Posters are non-sensitive public artwork, so explicit-sign-out clearing is sufficient for v1.

- [ ] **Step 2: Build, launch, and screenshot the gallery**

```
mcp__xcodebuildmcp__build_run_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED` and the app launches. Then drive the UI to the gallery and capture it:

```
mcp__xcodebuildmcp__snapshot_ui   (find the "Gallery" tab)
mcp__xcodebuildmcp__tap           (tap the "Gallery" tab)
mcp__xcodebuildmcp__screenshot
```

Expected screenshot: a "Design System" list with sections **PosterImage** (a real poster + two film/tv fallbacks), **PosterGrid + PosterSizeSlider** (slider above a reflowing grid), **Skeletons** (pulsing 2:3 cells), and **Empty / Error states** (a "No movies available" empty state and a "Something went wrong" + Retry error state). Drag the slider and confirm the grid column count changes.

- [ ] **Step 3: Verify the full headless suite still passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (21 total — Tasks 1–2 added 10).

- [ ] **Step 4: Commit**

```bash
git add App/SignedInPlaceholderView.swift
git commit -m "feat(app): clear poster cache on sign-out; verify DesignSystem gallery"
```

- [ ] **Step 5: Update the tracker**

In `docs/TRACKER.md`, mark F1.7 done — change line 29 from:

```markdown
- [ ] **F1.7** [Design system & image loading](superpowers/specs/01-foundations/design-system-image-loading.md) — Nuke posters, adaptive grid, skeletons
```

to:

```markdown
- [x] **F1.7** [Design system & image loading](superpowers/specs/01-foundations/design-system-image-loading.md) — Nuke posters, adaptive grid, skeletons
```

Then commit:

```bash
git add docs/TRACKER.md
git commit -m "docs: mark F1.7 (design system & image loading) done"
```

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/01-foundations/design-system-image-loading.md`):
- "Nuke image cache + a poster image view (high poster throughput)" → Task 3 (`PosterImagePipeline` with on-disk `DataCache`) + Task 4 (`PosterImage` via `LazyImage`). ✓
- "Adaptive `LazyVGrid` poster grid with a sensible minimum item width" → Task 5 (`PosterGrid` with `GridItem(.adaptive(minimum:))`). ✓
- "A **persisted** poster-size preference … shared, persisted UI store with a mobile-aware step" → Tasks 1–2 (`PosterGridMetrics` + persisted `PosterSizePreference`) + Task 5 (`PosterSizeSlider` mobile-aware step, shared instance). ✓
- "Reusable loading skeletons and empty/error components" → Task 6 (skeletons) + Task 7 (empty/error). ✓
- iOS notes: "`DesignSystem` package (its own plan)" → Task 3. "persist poster size in a preference store shared across media surfaces" → Task 2 + resolved open question (global). "Consider clearing the Nuke cache on sign-out" → Task 8. ✓
- Open questions: both resolved explicitly in Global Constraints (control on phone = yes with mobile-aware step; preference = shared/global). ✓
- Dependencies: "None (consumed by Epic 03 Discovery)" — honored; no networking/contract work here, and image-URL construction is explicitly deferred to Epic 03. ✓

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N". Every code step shows complete code; every command states expected output. The one cross-task file (the gallery) is edited via explicit, anchored replacements of stub properties — no "fill in later". ✓

**3. Type consistency:** Names match across tasks — `PosterGridMetrics.{minSize,maxSize,defaultSize,compactStep,regularStep,spacing,clamp,step}`; `PosterSizeStoring.{loadPosterSize,savePosterSize}`; `UserDefaultsPosterSizeStore(defaults:)`; `PosterSizePreference(store:).{size,setSize}`; `PosterImagePipeline.{configure,clearImageCache}`; `PosterKind.{movie,series}`; `PosterImage(url:kind:cornerRadius:)`; `PosterGrid(items:minItemWidth:spacing:cell:)`; `PosterSizeSlider(preference:)`; `PosterCellSkeleton(cornerRadius:)`, `PosterGridSkeleton(count:minItemWidth:spacing:)`, `SearchLoadingSkeleton(count:)`; `EmptyStateView(title:systemImage:description:)`, `ErrorStateView(message:retry:)`; `DesignSystemGalleryView` section properties `posterImageSection/posterGridSection/skeletonSection/statesSection`. The `.pulsing()` modifier defined in Task 4 is reused by `PosterCellSkeleton` in Task 6. `PosterSizePreference` is created in the app (`UserDefaultsPosterSizeStore`) the same way it is in the gallery. ✓

**Notes for the implementer:**
- Tasks 1–2 are headless: `cd Packages/SlipStreamKit && swift test`. Tasks 3–8 build/run via XcodeBuildMCP on `iPhone 17` (also sanity-check `iPad Pro 13-inch (M4)` once, to confirm the adaptive grid widens).
- The only manual Xcode step is Task 3 Step 5 (link the local `DesignSystem` package into the app target); everything else is plain-file edits, per CLAUDE.md's "keep `.xcodeproj` edits minimal".
- If Nuke's pinned version does not resolve on the toolchain, follow Task 3 Step 2's fallback note — the APIs used are stable across Nuke 12–13.
- Before merging to `main`, run `/code-review` per CLAUDE.md and squash-merge.
