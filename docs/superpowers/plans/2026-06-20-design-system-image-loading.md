# Design System & Visual Identity (F1.7) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `DesignSystem` SwiftUI package that gives the iOS app SlipStream's full visual identity — a force-dark token palette (movie-orange / tv-blue brand accents + media gradient), Inter typography, Nuke-backed poster loading, an adaptive poster grid, loading skeletons, empty/error states, brand logo/glow, and the request-status palette — plus the pure, headlessly-tested sizing/constants logic those views depend on (in `SlipStreamKit`).

**Architecture:** Pure, platform-agnostic values (grid metrics, the persisted poster-size preference, radius/type constants) live in **`SlipStreamKit`** so they run under the existing headless `swift test` loop on the Mac host. All SwiftUI — the force-dark `DesignTheme` colour tokens, Inter font ramp, components, brand pieces, and the status palette — lives in a **new iOS-only `DesignSystem` package** (mirroring `Feature-Auth`), depending on `SlipStreamKit` and on **Nuke** (`NukeUI.LazyImage` + `Nuke.ImagePipeline`). A DEBUG-only `DesignSystemGalleryView` is surfaced through a floating button → `.sheet` in `RootView` (no nested `TabView`), so every component is verifiable on the simulator without signing in. App integration is **surgical** (anchored edits, never whole-file replacement) to preserve the F1.4/F1.5/F1.6 wiring in `SlipStreamApp.swift` / `RootView.swift`.

**Tech Stack:** Swift 6.2 (strict concurrency), SwiftUI, `@Observable` (Observation), Swift Package Manager (local path packages + one remote dependency: Nuke 12), Swift Testing, Nuke (`NukeUI`, `Nuke`), Inter Variable (OFL), XcodeBuildMCP for simulator build/test/screenshot.

## Global Constraints

These are copied from the foundation plan and the F1.7 spec; every task implicitly inherits them.

- **Language/mode:** Swift 6.2, strict concurrency. Every type crossing a concurrency boundary is `Sendable`; UI/state types are `@MainActor`.
- **Deployment target:** iOS/iPadOS **26.0** minimum. `SlipStreamKit` additionally supports **macOS 14** so its pure-logic tests run via `swift test`. The new `DesignSystem` package is **iOS-only** (`.iOS(.v26)`), like `Feature-Auth`.
- **Appearance:** **force dark only** — the app applies `.preferredColorScheme(.dark)`. A single dark token set; no light theme in v1.
- **Bundle id:** `dev.jatassi.slipstream`. **Signing:** free Apple Personal Team. No paid entitlements.
- **One adaptive SwiftUI layer** serves iPhone, iPad, and Mac (Designed-for-iPad). Use size classes; do not branch on platform.
- **Reuse existing contract enums:** the accent is the existing `ModuleType { movie, tv }` (`SlipStreamKit/Models/ModuleType.swift`); the status palette maps the existing `RequestStatus` (`SlipStreamKit/Models/Enums.swift`, 8 cases). **Do not introduce a `PosterKind` enum.**
- **Contract / source of truth (web portal):** `~/Git/SlipStream/web/src`. Values mirrored here come from `index.css` (tokens), `lib/request-status-config.tsx` (status colours), `components/media/poster-image.tsx` + `components/search/*-card.tsx` (poster styling), `routes/requests/library.tsx` (`PosterSizeSlider`, `GridSkeleton`), `stores/ui.ts` (`posterSize`), `routes/requests/search-loading-skeleton.tsx`, `components/data/empty-state.tsx` + `error-state.tsx`. **Do not invent values** — they are pinned in Tasks 1 & 4.
- **Colour values:** SwiftUI has no OKLCH initializer. The web's OKLCH tokens were converted to sRGB (documented inline with their OKLCH source). Use the exact hex in Task 4.
- **Image URLs are NOT built here.** `PosterImage` consumes a server-resolved `URL?`. The artwork/TMDB URL chain is Epic 03's concern — out of scope.
- **Build/test:** use XcodeBuildMCP, never raw `xcodebuild`. Scheme `SlipStream`; simulators `iPhone 17`, `iPad Pro 13-inch (M4)`. Headless logic: `cd Packages/SlipStreamKit && swift test`.
- **Commits:** one per task minimum. Solo repo; the executing skill manages branching/worktree.
- **Integration discipline:** modify `App/SlipStreamApp.swift` and `App/RootView.swift` with **anchored edits only**. Never replace these files wholesale — they carry F1.4 (`SystemStore.refresh`), F1.5 (`PollingEngine`), and F1.6 (`AppShellView`, `NavigationModel`) wiring that must survive.

### Poster facts (pinned)

- Min item width range **100–250**, default **150**, slider step **25 compact / 10 regular**, persisted, **shared globally**. Grid = `GridItem(.adaptive(minimum: size))`.
- Aspect ratio **2:3**, corner radius **7pt** (`rounded-lg`, `--radius: 0.45rem`). Muted-fill **pulse** placeholder; film/tv SF-Symbol fallback. Media grid gap **12pt** (`gap-3`, re-verified current source); search skeleton gap **12pt**.

---

## File structure (this plan)

```
SlipStream-iOS/
  App/
    SlipStreamApp.swift                 # MODIFY (anchored): bootstrap + dark + inject preference (Task 4)
    RootView.swift                      # MODIFY (anchored): DEBUG gallery sheet + cache-clear (Task 4)
  Packages/
    SlipStreamKit/
      Sources/SlipStreamKit/Design/
        PosterGridMetrics.swift         # pure sizing: range/default/step/clamp (Task 1)
        PosterSizeStore.swift           # PosterSizeStoring + UserDefaultsPosterSizeStore (Task 2)
        PosterSizePreference.swift      # @MainActor @Observable preference (Task 2)
        DesignConstants.swift           # RadiusScale + TypeScale (Task 3)
      Tests/SlipStreamKitTests/
        PosterGridMetricsTests.swift    # (Task 1)
        PosterSizeFakes.swift           # FakePosterSizeStore (Task 2)
        PosterSizePreferenceTests.swift # (Task 2)
        DesignConstantsTests.swift      # (Task 3)
    DesignSystem/                        # NEW iOS-only package (Task 4)
      Package.swift                      # iOS 26; deps: ../SlipStreamKit + Nuke; Inter resource (Tasks 4,5)
      Sources/DesignSystem/
        Color+Hex.swift                  # Color(hex:) initializer (Task 4)
        DesignTheme.swift                # force-dark tokens + ModuleType accent + bootstrap (Task 4)
        PosterImagePipeline.swift        # Nuke pipeline + clearImageCache (Task 4)
        DesignSystemGalleryView.swift    # DEBUG catalog; themeSection filled, rest stubbed (Task 4)
        Typography.swift                 # Inter registration + Font ramp (Task 5)
        Resources/Fonts/InterVariable.ttf# bundled font (Task 5)
        Pulse.swift                      # .pulsing() + .shimmering() (Task 6)
        Glow.swift                       # .glow(_:) movie/tv neon shadow (Task 6)
        PosterImage.swift                # Nuke-backed 2:3 poster (Task 6)
        PosterGrid.swift                 # adaptive LazyVGrid (Task 7)
        PosterSizeSlider.swift           # size control bound to the preference (Task 7)
        Skeletons.swift                  # cell/grid/search skeletons (Task 8)
        StateViews.swift                 # EmptyStateView + ErrorStateView (Task 9)
        Brand.swift                      # SlipStreamLogoMark + wordmark (Task 10)
        StatusPalette.swift              # RequestStatus → colour/icon + StatusBadge (Task 11)
  SlipStream.xcodeproj/project.pbxproj   # MODIFY: link DesignSystem product (Task 4)
```

**External dependency added:** Nuke (`https://github.com/kean/Nuke`), products `NukeUI` + `Nuke` — the project's first and only third-party dependency, declared by `DesignSystem`.

---

### Task 1: Poster grid metrics (pure, headless TDD)

Pure sizing constants + helpers consumed by the preference (clamping) and the grid/slider. No SwiftUI — runs under `swift test`.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterGridMetrics.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterGridMetricsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum PosterGridMetrics` with static `CGFloat` `minSize=100`, `maxSize=250`, `defaultSize=150`, `compactStep=25`, `regularStep=10`, `spacing=12`.
  - `static func clamp(_ size: CGFloat) -> CGFloat` (into `minSize...maxSize`).
  - `static func step(isCompact: Bool) -> CGFloat`.

- [ ] **Step 1: Verify the pinned spacing against current web source**

Run: `grep -rn "gap-" ~/Git/SlipStream/web/src/components/search/expandable-media-grid.tsx ~/Git/SlipStream/web/src/routes/requests/library.tsx ~/Git/SlipStream/web/src/routes/requests/search-loading-skeleton.tsx`
Expected: the media/search grids use `gap-3` (12px). If a grid instead shows `gap-4` (16px), set `spacing` to that grid's value and note it in the file's doc comment. (This step exists because the prior plan pinned 16; the survey found 12.)

- [ ] **Step 2: Write the failing metrics test**

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
    #expect(PosterGridMetrics.spacing == 12)
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

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'PosterGridMetrics' in scope`.

- [ ] **Step 4: Write the metrics**

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
  /// Grid gutter (web media grids use `gap-3` = 0.75rem).
  public static let spacing: CGFloat = 12

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

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (the 5 new metrics tests included).

- [ ] **Step 6: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterGridMetrics.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterGridMetricsTests.swift
git commit -m "feat(kit): add PosterGridMetrics mirroring web posterSize store"
```

---

### Task 2: Poster-size preference store (persisted, observable, headless TDD)

A persisted, observable poster-size preference — the iOS equivalent of the web's shared `posterSize` UI store. A `PosterSizeStoring` seam keeps it testable; `UserDefaultsPosterSizeStore` persists to `UserDefaults`. `PosterSizePreference` is `@MainActor @Observable` (same pattern as `AuthStore`).

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
  - `@MainActor @Observable final class PosterSizePreference` with `init(store: PosterSizeStoring)`, `var size: CGFloat` (`private(set)`), `func setSize(_ newSize: CGFloat)`.

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
Expected: all tests pass (5 new preference tests included).

- [ ] **Step 5: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterSizeStore.swift \
        Packages/SlipStreamKit/Sources/SlipStreamKit/Design/PosterSizePreference.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterSizeFakes.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/PosterSizePreferenceTests.swift
git commit -m "feat(kit): add persisted, observable PosterSizePreference"
```

---

### Task 3: Design constants — radius & type scale (pure, headless TDD)

The pure presentation constants the `DesignSystem` consumes: the corner-radius scale (`--radius: 0.45rem`) and the type-ramp point sizes (mirroring the web's `text-*` usage). Pure `CGFloat` — runs headlessly.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Design/DesignConstants.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/DesignConstantsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum RadiusScale` with static `CGFloat` `small=4`, `base=7`, `pill=999`.
  - `enum TypeScale` with static `CGFloat` `pageTitle=24`, `section=20`, `cardTitle=16`, `body=14`, `metadata=12`, `badge=10`.

- [ ] **Step 1: Write the failing constants test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/DesignConstantsTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import SlipStreamKit

@Suite struct DesignConstantsTests {
  @Test func radiusScaleMatchesWebRadius() {
    // --radius: 0.45rem ≈ 7pt (Tailwind rounded-lg); badges are pill-shaped.
    #expect(RadiusScale.base == 7)
    #expect(RadiusScale.small == 4)
    #expect(RadiusScale.pill == 999)
  }

  @Test func typeScaleMatchesWebSizes() {
    #expect(TypeScale.pageTitle == 24)
    #expect(TypeScale.section == 20)
    #expect(TypeScale.cardTitle == 16)
    #expect(TypeScale.body == 14)
    #expect(TypeScale.metadata == 12)
    #expect(TypeScale.badge == 10)
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'RadiusScale' in scope`.

- [ ] **Step 3: Write the constants**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Design/DesignConstants.swift`:

```swift
import CoreGraphics

/// Corner-radius scale mirroring the web `--radius: 0.45rem` token
/// (`web/src/index.css`). `base` ≈ Tailwind `rounded-lg`; badges use `pill`.
public enum RadiusScale {
  public static let small: CGFloat = 4
  public static let base: CGFloat = 7
  public static let pill: CGFloat = 999
}

/// Type-ramp point sizes mirroring the web portal's `text-*` usage: page title
/// (`text-2xl`), section (`text-xl`), card title (`text-base`), body (`text-sm`),
/// metadata (`text-xs`), badge (`text-[10px]`).
public enum TypeScale {
  public static let pageTitle: CGFloat = 24
  public static let section: CGFloat = 20
  public static let cardTitle: CGFloat = 16
  public static let body: CGFloat = 14
  public static let metadata: CGFloat = 12
  public static let badge: CGFloat = 10
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (2 new constants tests included).

- [ ] **Step 5: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Design/DesignConstants.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/DesignConstantsTests.swift
git commit -m "feat(kit): add RadiusScale + TypeScale design constants"
```

---

### Task 4: DesignSystem package + force-dark theme + Nuke pipeline + app integration

Stand up the iOS-only `DesignSystem` package, add Nuke, define the force-dark colour tokens, configure the image pipeline, link the package into the app, and wire it in **surgically**: bootstrap at launch, force dark, inject a shared `PosterSizePreference`, and surface a DEBUG gallery (theme swatches now; components stubbed). Deliverable: the app builds & launches in forced dark with all F1.4/F1.5/F1.6 wiring intact, and a floating DEBUG button opens a themed "Design System" sheet showing the colour palette.

**Files:**
- Create: `Packages/DesignSystem/Package.swift`
- Create: `Packages/DesignSystem/Sources/DesignSystem/Color+Hex.swift`
- Create: `Packages/DesignSystem/Sources/DesignSystem/DesignTheme.swift`
- Create: `Packages/DesignSystem/Sources/DesignSystem/PosterImagePipeline.swift`
- Create: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift`
- Modify: `SlipStream.xcodeproj/project.pbxproj` (link DesignSystem)
- Modify: `App/SlipStreamApp.swift` (anchored)
- Modify: `App/RootView.swift` (anchored)

**Interfaces:**
- Consumes: `PosterSizePreference`, `UserDefaultsPosterSizeStore`, `ModuleType` (Kit).
- Produces:
  - `extension Color { init(hex: UInt32) }`
  - `enum DesignTheme` with static `Color` tokens (`background`, `surface`, `foreground`, `muted`, `mutedForeground`, `accent`, `ring`, `destructive`, `border`, `movie`, `movieMuted`, `movieVibrant`, `tv`, `tvMuted`, `tvVibrant`), `static let mediaGradient: LinearGradient`, and `static func bootstrap()`.
  - `extension ModuleType { var accentColor: Color; var fallbackSymbol: String }`
  - `enum PosterImagePipeline { static func configure(); static func clearImageCache() }`
  - `struct DesignSystemGalleryView: View` with `init()` and `@ViewBuilder` section properties `themeSection` (filled), `typographySection`/`posterImageSection`/`posterGridSection`/`skeletonSection`/`statesSection`/`brandSection`/`statusSection` (stubbed to `EmptyView()`).

- [ ] **Step 1: Create the package manifest**

Create `Packages/DesignSystem/Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "DesignSystem",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "DesignSystem", targets: ["DesignSystem"])
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
    )
  ]
)
```

- [ ] **Step 2: Verify Nuke resolves**

Run: `cd Packages/DesignSystem && swift package resolve`
Expected: Nuke resolves to a `12.x` version, writing `Package.resolved`. (Resolution reads the manifest only — it does not compile, so the iOS-only platform is fine on the Mac host.) If the toolchain rejects `12.8.0`, raise the lower bound to the latest tag printed; the `LazyImage` / `ImagePipeline.shared` / `cache.removeAll()` APIs are unchanged across Nuke 12–13.

- [ ] **Step 3: Write the hex Color initializer**

Create `Packages/DesignSystem/Sources/DesignSystem/Color+Hex.swift`:

```swift
import SwiftUI

extension Color {
  /// Build an sRGB colour from a `0xRRGGBB` literal. Used by `DesignTheme` for
  /// the web tokens (whose OKLCH values were converted to sRGB hex).
  init(hex: UInt32) {
    let r = Double((hex >> 16) & 0xFF) / 255
    let g = Double((hex >> 8) & 0xFF) / 255
    let b = Double(hex & 0xFF) / 255
    self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
  }
}
```

- [ ] **Step 4: Write the force-dark theme + ModuleType accent**

Create `Packages/DesignSystem/Sources/DesignSystem/DesignTheme.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// SlipStream's force-dark visual identity. Colours mirror the web portal's
/// dark-theme tokens in `web/src/index.css`; the web defines them in OKLCH, which
/// SwiftUI cannot express directly, so each is converted to sRGB hex with its
/// OKLCH source noted inline. The app runs dark-only (`.preferredColorScheme(.dark)`).
public enum DesignTheme {
  // MARK: Semantic
  public static let background = Color(hex: 0x0A0A0A)       // oklch(0.145 0 0)
  public static let surface = Color(hex: 0x171717)         // oklch(0.205 0 0) — card
  public static let foreground = Color(hex: 0xFAFAFA)      // oklch(0.985 0 0)
  public static let muted = Color(hex: 0x262626)           // oklch(0.269 0 0)
  public static let mutedForeground = Color(hex: 0xA1A1A1) // oklch(0.708 0 0)
  public static let accent = Color(hex: 0x404040)          // oklch(0.371 0 0)
  public static let ring = Color(hex: 0x737373)            // oklch(0.556 0 0)
  public static let destructive = Color(hex: 0xFF6467)     // oklch(0.704 0.191 22.216)
  public static let border = Color.white.opacity(0.10)     // white @ 10%

  // MARK: Brand — movie (orange) / tv (blue)
  public static let movie = Color(hex: 0xEF852E)           // oklch(0.72 0.16 55) — movie-500
  public static let movieMuted = Color(hex: 0xB6501F)      // movie-700
  public static let movieVibrant = Color(hex: 0xF29E46)    // movie-400
  public static let tv = Color(hex: 0x009FF6)              // oklch(0.675 0.17 243) — tv-500
  public static let tvMuted = Color(hex: 0x0066B0)         // tv-700
  public static let tvVibrant = Color(hex: 0x26B7FF)       // tv-400

  /// The SlipStream brand gradient: movie-orange → tv-blue, left to right
  /// (web `bg-media-gradient`).
  public static let mediaGradient = LinearGradient(
    colors: [movie, tv], startPoint: .leading, endPoint: .trailing)

  /// Install runtime design dependencies once, at launch, before any view renders.
  /// (Inter font registration is added in Task 5.)
  @MainActor public static func bootstrap() {
    PosterImagePipeline.configure()
  }
}

/// Maps the contract's media type to its brand accent and fallback glyph — the
/// iOS analogue of the web's per-type tinting (`movie` orange / `tv` blue) and
/// `FallbackIcon` (`Film` / `Tv`).
extension ModuleType {
  public var accentColor: Color {
    switch self {
    case .movie: DesignTheme.movie
    case .tv: DesignTheme.tv
    }
  }

  public var fallbackSymbol: String {
    switch self {
    case .movie: "film"
    case .tv: "tv"
    }
  }
}
```

- [ ] **Step 5: Write the Nuke image pipeline**

Create `Packages/DesignSystem/Sources/DesignSystem/PosterImagePipeline.swift`:

```swift
import Nuke

/// The shared Nuke pipeline for poster/backdrop artwork. Adds an on-disk
/// `DataCache` on top of Nuke's in-memory cache for high poster throughput, and
/// exposes a cache-clear used on sign-out (shared family device).
public enum PosterImagePipeline {
  /// Install the poster pipeline as `ImagePipeline.shared`. Call once at launch.
  public static func configure() {
    let pipeline = ImagePipeline {
      $0.dataCache = try? DataCache(name: "dev.jatassi.slipstream.posters")
      $0.dataCachePolicy = .automatic
    }
    ImagePipeline.shared = pipeline
  }

  /// Drop all cached artwork (memory + disk). Called when the session ends.
  public static func clearImageCache() {
    ImagePipeline.shared.cache.removeAll()
  }
}
```

- [ ] **Step 6: Write the gallery harness (theme section filled, rest stubbed)**

Create `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// A DEBUG-only living catalog of DesignSystem components, surfaced via a floating
/// button → sheet in `RootView` so each piece is verifiable on the simulator
/// without signing in. Tasks 5–11 replace the `EmptyView()` stubs with real content.
public struct DesignSystemGalleryView: View {
  @State private var posterSize = PosterSizePreference(store: UserDefaultsPosterSizeStore())

  public init() {}

  public var body: some View {
    List {
      themeSection
      typographySection
      posterImageSection
      posterGridSection
      skeletonSection
      statesSection
      brandSection
      statusSection
    }
    .navigationTitle("Design System")
    .listStyle(.insetGrouped)
  }

  @ViewBuilder private var themeSection: some View {
    Section("Theme") {
      let swatches: [(String, Color)] = [
        ("background", DesignTheme.background), ("surface", DesignTheme.surface),
        ("foreground", DesignTheme.foreground), ("muted", DesignTheme.muted),
        ("mutedFg", DesignTheme.mutedForeground), ("border", DesignTheme.border),
        ("destructive", DesignTheme.destructive), ("movie", DesignTheme.movie),
        ("tv", DesignTheme.tv),
      ]
      ForEach(swatches, id: \.0) { name, color in
        HStack {
          RoundedRectangle(cornerRadius: RadiusScale.small)
            .fill(color)
            .frame(width: 44, height: 28)
            .overlay(RoundedRectangle(cornerRadius: RadiusScale.small).stroke(DesignTheme.border))
          Text(name)
        }
      }
      RoundedRectangle(cornerRadius: RadiusScale.base)
        .fill(DesignTheme.mediaGradient)
        .frame(height: 28)
        .overlay(Text("media gradient").font(.caption).foregroundStyle(.white))
    }
  }

  @ViewBuilder private var typographySection: some View { EmptyView() }
  @ViewBuilder private var posterImageSection: some View { EmptyView() }
  @ViewBuilder private var posterGridSection: some View { EmptyView() }
  @ViewBuilder private var skeletonSection: some View { EmptyView() }
  @ViewBuilder private var statesSection: some View { EmptyView() }
  @ViewBuilder private var brandSection: some View { EmptyView() }
  @ViewBuilder private var statusSection: some View { EmptyView() }
}
```

- [ ] **Step 7: Link DesignSystem into the app target (project.pbxproj)**

The project links local packages through `project.pbxproj` (no `.xcworkspace`). Make four anchored edits to `SlipStream.xcodeproj/project.pbxproj`, mirroring the existing `FeatureShell` entries.

Edit 7a — add the product dependency to the app target's `packageProductDependencies`. Replace:

```
				1A1A1A1A1A1A1A1A1A1A0023 /* FeatureShell */,
			);
			productName = MyApp;
```

with:

```
				1A1A1A1A1A1A1A1A1A1A0023 /* FeatureShell */,
				1A1A1A1A1A1A1A1A1A1A0033 /* DesignSystem */,
			);
			productName = MyApp;
```

Edit 7b — register the local package reference. Replace:

```
				1A1A1A1A1A1A1A1A1A1A0022 /* XCLocalSwiftPackageReference "Packages/Feature-Shell" */,
			);
			preferredProjectObjectVersion = 90;
```

with:

```
				1A1A1A1A1A1A1A1A1A1A0022 /* XCLocalSwiftPackageReference "Packages/Feature-Shell" */,
				1A1A1A1A1A1A1A1A1A1A0032 /* XCLocalSwiftPackageReference "Packages/DesignSystem" */,
			);
			preferredProjectObjectVersion = 90;
```

Edit 7c — add the `XCLocalSwiftPackageReference` object. Replace:

```
		1A1A1A1A1A1A1A1A1A1A0022 /* XCLocalSwiftPackageReference "Packages/Feature-Shell" */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = Packages/Feature-Shell;
		};
/* End XCLocalSwiftPackageReference section */
```

with:

```
		1A1A1A1A1A1A1A1A1A1A0022 /* XCLocalSwiftPackageReference "Packages/Feature-Shell" */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = Packages/Feature-Shell;
		};
		1A1A1A1A1A1A1A1A1A1A0032 /* XCLocalSwiftPackageReference "Packages/DesignSystem" */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = Packages/DesignSystem;
		};
/* End XCLocalSwiftPackageReference section */
```

Edit 7d — add the `XCSwiftPackageProductDependency` object. Replace:

```
		1A1A1A1A1A1A1A1A1A1A0023 /* FeatureShell */ = {
			isa = XCSwiftPackageProductDependency;
			productName = FeatureShell;
		};
/* End XCSwiftPackageProductDependency section */
```

with:

```
		1A1A1A1A1A1A1A1A1A1A0023 /* FeatureShell */ = {
			isa = XCSwiftPackageProductDependency;
			productName = FeatureShell;
		};
		1A1A1A1A1A1A1A1A1A1A0033 /* DesignSystem */ = {
			isa = XCSwiftPackageProductDependency;
			productName = DesignSystem;
		};
/* End XCSwiftPackageProductDependency section */
```

- [ ] **Step 8: Wire the app launch — `SlipStreamApp.swift` (anchored edits)**

Make three anchored edits to `App/SlipStreamApp.swift`. Do **not** replace the file.

Edit 8a — add the import. Replace:

```swift
import SlipStreamKit
import SwiftUI
```

with:

```swift
import DesignSystem
import SlipStreamKit
import SwiftUI
```

Edit 8b — add the shared preference state and bootstrap at launch. Replace:

```swift
  @State private var navigation = NavigationModel()

  init() {
    let initialAuth = AuthStore(
```

with:

```swift
  @State private var navigation = NavigationModel()
  @State private var posterSize = PosterSizePreference(store: UserDefaultsPosterSizeStore())

  init() {
    // Install the Nuke poster pipeline (and, from F1.7 Task 5, the Inter
    // typeface) before any view renders.
    DesignTheme.bootstrap()
    let initialAuth = AuthStore(
```

Edit 8c — inject the preference and force dark. Replace:

```swift
        .environment(navigation)
    }
  }
}
```

with:

```swift
        .environment(navigation)
        .environment(posterSize)
        .preferredColorScheme(.dark)
    }
  }
}
```

- [ ] **Step 9: Wire `RootView.swift` — cache-clear + DEBUG gallery (anchored edits)**

Make three anchored edits to `App/RootView.swift`. Do **not** replace the file.

Edit 9a — add the import. Replace:

```swift
import FeatureAuth
import FeatureShell
import SlipStreamKit
import SwiftUI
```

with:

```swift
import DesignSystem
import FeatureAuth
import FeatureShell
import SlipStreamKit
import SwiftUI
```

Edit 9b — add the auth environment + gallery state. Replace:

```swift
  @Environment(\.scenePhase) private var scenePhase
  @Environment(PollingEngine.self) private var poller
  @Environment(SystemStore.self) private var system
```

with:

```swift
  @Environment(\.scenePhase) private var scenePhase
  @Environment(AuthStore.self) private var auth
  @Environment(PollingEngine.self) private var poller
  @Environment(SystemStore.self) private var system

  #if DEBUG
  @State private var showingGallery = false
  #endif
```

Edit 9c — add the cache-clear and DEBUG gallery surface. Replace:

```swift
    .onChange(of: scenePhase, initial: true) { _, phase in
      poller.setActivity(activity(for: phase))
    }
  }
```

with:

```swift
    .onChange(of: scenePhase, initial: true) { _, phase in
      poller.setActivity(activity(for: phase))
    }
    // Drop cached poster artwork whenever the session ends — manual sign-out or
    // F2.4's future 401 auto-logout. Shared family device. (F1.7)
    .onChange(of: auth.state) { _, state in
      if state == .signedOut { PosterImagePipeline.clearImageCache() }
    }
    #if DEBUG
    .overlay(alignment: .bottomTrailing) { galleryButton }
    .sheet(isPresented: $showingGallery) {
      NavigationStack { DesignSystemGalleryView() }
    }
    #endif
  }

  #if DEBUG
  /// A floating DEBUG-only affordance that opens the DesignSystem gallery from
  /// anywhere (including signed-out), without nesting a `TabView` in the shell.
  private var galleryButton: some View {
    Button {
      showingGallery = true
    } label: {
      Image(systemName: "swatchpalette.fill")
        .padding(12)
        .background(.ultraThinMaterial, in: Circle())
    }
    .padding()
    .accessibilityLabel("Design System Gallery")
  }
  #endif
```

- [ ] **Step 10: Build and launch on the simulator**

```
mcp__xcodebuildmcp__build_run_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED`; the app launches **in dark mode** at the normal sign-in screen with a floating swatch button at bottom-trailing. If Nuke fails to link, confirm Edits 7a–7d applied (matching IDs) and rebuild.

- [ ] **Step 11: Verify the gallery opens and the theme renders**

```
mcp__xcodebuildmcp__tap            (tap the floating swatch button)
mcp__xcodebuildmcp__screenshot
```

Expected: a dark "Design System" sheet with a **Theme** section — colour swatches (background near-black, surface dark gray, movie orange, tv blue, etc.) and a horizontal orange→blue media-gradient bar. Dismiss the sheet.

- [ ] **Step 12: Confirm no regression — headless suite still green**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (the F1.4/F1.5/F1.6 suites plus Tasks 1–3).

- [ ] **Step 13: Commit**

```bash
git add Packages/DesignSystem App/SlipStreamApp.swift App/RootView.swift SlipStream.xcodeproj/project.pbxproj
git commit -m "feat(ds): scaffold DesignSystem, force-dark theme, Nuke pipeline, DEBUG gallery"
```

---

### Task 5: Typography — bundle Inter Variable + Font ramp

Bundle the Inter Variable typeface (OFL) as a package resource, register it at launch, and expose a `Font` ramp mirroring the web's `Inter Variable` usage and `text-*` sizes (`TypeScale`). Dynamic Type is respected via `relativeTo:`.

**Files:**
- Create: `Packages/DesignSystem/Sources/DesignSystem/Resources/Fonts/InterVariable.ttf`
- Create: `Packages/DesignSystem/Sources/DesignSystem/Typography.swift`
- Modify: `Packages/DesignSystem/Package.swift` (declare the font resource)
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignTheme.swift` (register fonts in `bootstrap`)
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift` (fill `typographySection`)

**Interfaces:**
- Consumes: `TypeScale` (Task 3).
- Produces:
  - `enum Typography { static func registerFonts() }`
  - `extension Font` ramp: `ssPageTitle`, `ssSection`, `ssCardTitle`, `ssBody`, `ssMetadata`, `ssBadge`.

- [ ] **Step 1: Fetch the Inter Variable font file**

Run (downloads the OFL release and copies the upright variable face into the package):

```bash
mkdir -p Packages/DesignSystem/Sources/DesignSystem/Resources/Fonts
curl -fL -o /tmp/inter.zip https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip
unzip -oq /tmp/inter.zip -d /tmp/inter
cp "$(find /tmp/inter -iname 'InterVariable.ttf' | head -1)" \
   Packages/DesignSystem/Sources/DesignSystem/Resources/Fonts/InterVariable.ttf
ls -la Packages/DesignSystem/Sources/DesignSystem/Resources/Fonts/InterVariable.ttf
```

Expected: a non-empty `InterVariable.ttf` (~800KB+). If the `v4.1` URL 404s, substitute the latest tag from `https://github.com/rsms/inter/releases` (the file name `InterVariable.ttf` is stable). The PostScript name is `InterVariable` (used in Step 3).

- [ ] **Step 2: Declare the resource in the manifest**

In `Packages/DesignSystem/Package.swift`, replace:

```swift
    .target(
      name: "DesignSystem",
      dependencies: [
        "SlipStreamKit",
        .product(name: "NukeUI", package: "Nuke"),
        .product(name: "Nuke", package: "Nuke"),
      ]
    )
```

with:

```swift
    .target(
      name: "DesignSystem",
      dependencies: [
        "SlipStreamKit",
        .product(name: "NukeUI", package: "Nuke"),
        .product(name: "Nuke", package: "Nuke"),
      ],
      resources: [.copy("Resources/Fonts/InterVariable.ttf")]
    )
```

- [ ] **Step 3: Write the typography registration + Font ramp**

Create `Packages/DesignSystem/Sources/DesignSystem/Typography.swift`:

```swift
import SwiftUI
import CoreText
import SlipStreamKit

/// Registers the bundled Inter Variable typeface and exposes the SlipStream font
/// ramp. Inter is the web portal's `--font-sans`; sizes mirror its `text-*` usage
/// via `TypeScale`. Call `registerFonts()` once at launch (from `DesignTheme.bootstrap`).
public enum Typography {
  /// PostScript name of the bundled variable face.
  static let familyName = "InterVariable"

  public static func registerFonts() {
    guard let url = Bundle.module.url(forResource: "InterVariable", withExtension: "ttf") else {
      return
    }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }
}

extension Font {
  /// Page title — `text-2xl` semibold.
  public static let ssPageTitle =
    Font.custom(Typography.familyName, size: TypeScale.pageTitle, relativeTo: .title).weight(.semibold)
  /// Section heading — `text-xl` semibold.
  public static let ssSection =
    Font.custom(Typography.familyName, size: TypeScale.section, relativeTo: .title2).weight(.semibold)
  /// Card title — `text-base` medium.
  public static let ssCardTitle =
    Font.custom(Typography.familyName, size: TypeScale.cardTitle, relativeTo: .headline).weight(.medium)
  /// Body copy — `text-sm`.
  public static let ssBody =
    Font.custom(Typography.familyName, size: TypeScale.body, relativeTo: .body)
  /// Metadata / timestamps — `text-xs`.
  public static let ssMetadata =
    Font.custom(Typography.familyName, size: TypeScale.metadata, relativeTo: .caption)
  /// Badge label — `text-[10px]` medium.
  public static let ssBadge =
    Font.custom(Typography.familyName, size: TypeScale.badge, relativeTo: .caption2).weight(.medium)
}
```

- [ ] **Step 4: Register fonts at launch**

In `Packages/DesignSystem/Sources/DesignSystem/DesignTheme.swift`, replace:

```swift
  @MainActor public static func bootstrap() {
    PosterImagePipeline.configure()
  }
```

with:

```swift
  @MainActor public static func bootstrap() {
    PosterImagePipeline.configure()
    Typography.registerFonts()
  }
```

- [ ] **Step 5: Fill the gallery typography section**

In `DesignSystemGalleryView.swift`, replace:

```swift
  @ViewBuilder private var typographySection: some View { EmptyView() }
```

with:

```swift
  @ViewBuilder private var typographySection: some View {
    Section("Typography (Inter)") {
      Text("Page Title").font(.ssPageTitle)
      Text("Section Heading").font(.ssSection)
      Text("Card Title").font(.ssCardTitle)
      Text("Body copy — the quick brown fox.").font(.ssBody)
      Text("Metadata · 2026").font(.ssMetadata).foregroundStyle(DesignTheme.mutedForeground)
      Text("BADGE").font(.ssBadge)
    }
  }
```

- [ ] **Step 6: Build and screenshot the typography**

```
mcp__xcodebuildmcp__build_run_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Then `tap` the swatch button and `screenshot`. Expected: `BUILD SUCCEEDED`; the gallery now shows a **Typography (Inter)** section with the ramp rendered in Inter (note Inter's distinct lowercase `a`/`g` vs the system font). If the text falls back to San Francisco, re-check Step 1 (file present) and the PostScript name in Step 3.

- [ ] **Step 7: Commit**

```bash
git add Packages/DesignSystem/Package.swift \
        Packages/DesignSystem/Sources/DesignSystem/Resources/Fonts/InterVariable.ttf \
        Packages/DesignSystem/Sources/DesignSystem/Typography.swift \
        Packages/DesignSystem/Sources/DesignSystem/DesignTheme.swift \
        Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift
git commit -m "feat(ds): bundle Inter Variable + SlipStream font ramp"
```

---

### Task 6: PosterImage + pulse/shimmer + glow

The Nuke-backed poster view — a 2:3 rounded cell with a muted pulse while loading, image scaled-to-fill on success, and a `ModuleType`-tinted film/tv fallback on failure (web `PosterImage` + `FallbackIcon`). Adds the reusable `.pulsing()` / `.shimmering()` modifiers (web `animate-pulse` + `animate-skeleton-shimmer`) and the `.glow(_:)` neon shadow (web `glow-movie` / `glow-tv`).

**Files:**
- Create: `Packages/DesignSystem/Sources/DesignSystem/Pulse.swift`
- Create: `Packages/DesignSystem/Sources/DesignSystem/Glow.swift`
- Create: `Packages/DesignSystem/Sources/DesignSystem/PosterImage.swift`
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift` (fill `posterImageSection`)

**Interfaces:**
- Consumes: `NukeUI.LazyImage`, `DesignTheme`, `ModuleType` (accent + fallback), `RadiusScale`.
- Produces:
  - `func pulsing() -> some View`, `func shimmering() -> some View` (internal `View` extensions).
  - `func glow(_ color: Color, radius: CGFloat = 15) -> some View` and `func glow(_ module: ModuleType, radius: CGFloat = 15) -> some View` (public `View` extensions).
  - `struct PosterImage: View` with `init(url: URL?, module: ModuleType, cornerRadius: CGFloat = RadiusScale.base)`.

- [ ] **Step 1: Write the pulse + shimmer modifiers**

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

/// A light sweep across the view — the iOS analogue of the web
/// `animate-skeleton-shimmer` gradient that slides over each `Skeleton`.
private struct ShimmerModifier: ViewModifier {
  @State private var phase: CGFloat = -1

  func body(content: Content) -> some View {
    content
      .overlay {
        GeometryReader { geo in
          LinearGradient(
            colors: [.clear, .white.opacity(0.25), .clear],
            startPoint: .leading, endPoint: .trailing
          )
          .frame(width: geo.size.width)
          .offset(x: phase * geo.size.width * 2)
        }
      }
      .mask(content)
      .onAppear {
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
          phase = 1
        }
      }
  }
}

extension View {
  /// Apply the standard loading-placeholder pulse.
  func pulsing() -> some View { modifier(PulseModifier()) }
  /// Apply the standard skeleton shimmer sweep.
  func shimmering() -> some View { modifier(ShimmerModifier()) }
}
```

- [ ] **Step 2: Write the glow modifier**

Create `Packages/DesignSystem/Sources/DesignSystem/Glow.swift`:

```swift
import SwiftUI
import SlipStreamKit

extension View {
  /// A neon glow — the iOS analogue of the web's `glow-movie` / `glow-tv`
  /// (`box-shadow: 0 0 15px <accent>`). Apply to selected/active media cards.
  public func glow(_ color: Color, radius: CGFloat = 15) -> some View {
    shadow(color: color.opacity(0.85), radius: radius)
  }

  /// Glow tinted by media type (movie = orange, tv = blue).
  public func glow(_ module: ModuleType, radius: CGFloat = 15) -> some View {
    glow(module.accentColor, radius: radius)
  }
}
```

- [ ] **Step 3: Write the poster view**

Create `Packages/DesignSystem/Sources/DesignSystem/PosterImage.swift`:

```swift
import SwiftUI
import NukeUI
import SlipStreamKit

/// A cached poster image in the portal's 2:3 portrait format with a `rounded-lg`
/// corner. Shows a muted pulse while loading, scales the image to fill on
/// success, and falls back to a `ModuleType`-tinted film/tv glyph on failure
/// (web `PosterImage` + `FallbackIcon`). The `url` is the server-resolved
/// `posterUrl`; building artwork URLs is Epic 03's concern.
public struct PosterImage: View {
  private let url: URL?
  private let module: ModuleType
  private let cornerRadius: CGFloat

  public init(url: URL?, module: ModuleType, cornerRadius: CGFloat = RadiusScale.base) {
    self.url = url
    self.module = module
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
            DesignTheme.muted.pulsing()
          }
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(DesignTheme.border, lineWidth: 1)
      }
  }

  private var fallback: some View {
    ZStack {
      DesignTheme.muted
      Image(systemName: module.fallbackSymbol)
        .font(.system(size: 36))
        .foregroundStyle(module.accentColor)
    }
  }
}

#Preview("PosterImage") {
  HStack(spacing: 12) {
    PosterImage(url: nil, module: .movie)
    PosterImage(url: nil, module: .tv)
  }
  .frame(height: 240)
  .padding()
  .background(DesignTheme.background)
}
```

- [ ] **Step 4: Fill the gallery poster section**

In `DesignSystemGalleryView.swift`, replace:

```swift
  @ViewBuilder private var posterImageSection: some View { EmptyView() }
```

with:

```swift
  @ViewBuilder private var posterImageSection: some View {
    Section("PosterImage") {
      HStack(spacing: 12) {
        PosterImage(
          url: URL(string: "https://image.tmdb.org/t/p/w342/8IB2e4r4oVhHnANbnm7O3Tj6tF8.jpg"),
          module: .movie)
        PosterImage(url: nil, module: .movie)
        PosterImage(url: nil, module: .tv)
      }
      .frame(height: 180)
      PosterImage(url: nil, module: .movie)
        .frame(height: 150)
        .glow(.movie)
    }
  }
```

- [ ] **Step 5: Build to verify**

```
mcp__xcodebuildmcp__build_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED`. (The first cell loads a real poster when the sim has network; the others show the orange film / blue tv fallback. Full screenshot in Task 12.)

- [ ] **Step 6: Commit**

```bash
git add Packages/DesignSystem/Sources/DesignSystem/Pulse.swift \
        Packages/DesignSystem/Sources/DesignSystem/Glow.swift \
        Packages/DesignSystem/Sources/DesignSystem/PosterImage.swift \
        Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift
git commit -m "feat(ds): add Nuke-backed PosterImage with pulse/shimmer + glow"
```

---

### Task 7: Adaptive PosterGrid + PosterSizeSlider

The reusable adaptive poster grid (`GridItem(.adaptive(minimum:))`, the equivalent of the web's `repeat(auto-fill, minmax(posterSize, 1fr))`) and the poster-size control bound to the shared `PosterSizePreference`, with the mobile-aware step.

**Files:**
- Create: `Packages/DesignSystem/Sources/DesignSystem/PosterGrid.swift`
- Create: `Packages/DesignSystem/Sources/DesignSystem/PosterSizeSlider.swift`
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift` (fill `posterGridSection`)

**Interfaces:**
- Consumes: `PosterGridMetrics`, `PosterSizePreference` (Kit); `PosterImage` (Task 6).
- Produces:
  - `struct PosterGrid<Item: Identifiable, Cell: View>: View` with `init(items: [Item], minItemWidth: CGFloat, spacing: CGFloat = PosterGridMetrics.spacing, @ViewBuilder cell: @escaping (Item) -> Cell)`. Bare `LazyVGrid`; caller supplies the `ScrollView`.
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
      Image(systemName: "rectangle.grid.3x2")
        .foregroundStyle(DesignTheme.mutedForeground)
      Slider(
        value: Binding(
          get: { preference.size },
          set: { preference.setSize($0) }
        ),
        in: PosterGridMetrics.minSize...PosterGridMetrics.maxSize,
        step: step
      )
      .tint(DesignTheme.movie)
    }
  }
}
```

- [ ] **Step 3: Fill the gallery grid section**

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
        PosterImage(url: nil, module: poster.module)
      }
    }
  }
```

Then add this sample type at the end of the file (after the `}` that closes `struct DesignSystemGalleryView`):

```swift
/// Throwaway sample data for the gallery's grid section.
private struct GalleryPoster: Identifiable {
  let id: Int
  let module: ModuleType

  static let samples: [GalleryPoster] = (0..<8).map {
    GalleryPoster(id: $0, module: $0.isMultiple(of: 2) ? .movie : .tv)
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

Expected: `BUILD SUCCEEDED`. Dragging the slider reflows the grid (verified visually in Task 12).

- [ ] **Step 5: Commit**

```bash
git add Packages/DesignSystem/Sources/DesignSystem/PosterGrid.swift \
        Packages/DesignSystem/Sources/DesignSystem/PosterSizeSlider.swift \
        Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift
git commit -m "feat(ds): add adaptive PosterGrid and PosterSizeSlider"
```

---

### Task 8: Loading skeletons

The loading placeholders, mirroring the web `GridSkeleton` (12 muted 2:3 pulse cells) and `SearchLoadingSkeleton` (denser cells). Built from a `PosterCellSkeleton` primitive that combines the pulse and shimmer from Task 6.

**Files:**
- Create: `Packages/DesignSystem/Sources/DesignSystem/Skeletons.swift`
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift` (fill `skeletonSection`)

**Interfaces:**
- Consumes: `PosterGridMetrics`, `RadiusScale`, `DesignTheme`; `.pulsing()` + `.shimmering()` (Task 6).
- Produces:
  - `struct PosterCellSkeleton: View` with `init(cornerRadius: CGFloat = RadiusScale.base)`.
  - `struct PosterGridSkeleton: View` with `init(count: Int = 12, minItemWidth: CGFloat = PosterGridMetrics.defaultSize, spacing: CGFloat = PosterGridMetrics.spacing)`.
  - `struct SearchLoadingSkeleton: View` with `init(count: Int = 12)` (denser: `minItemWidth = 100`).

- [ ] **Step 1: Write the skeletons**

Create `Packages/DesignSystem/Sources/DesignSystem/Skeletons.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// One muted, pulsing-and-shimmering 2:3 poster placeholder — the web's
/// `bg-muted aspect-[2/3] animate-pulse rounded-lg` cell with the skeleton sweep.
public struct PosterCellSkeleton: View {
  private let cornerRadius: CGFloat

  public init(cornerRadius: CGFloat = RadiusScale.base) {
    self.cornerRadius = cornerRadius
  }

  public var body: some View {
    Color.clear
      .aspectRatio(2.0 / 3.0, contentMode: .fit)
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(DesignTheme.muted)
          .pulsing()
          .shimmering()
      }
  }
}

/// A full grid of poster placeholders, mirroring the web `GridSkeleton`
/// (12 cells, adaptive columns).
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
/// `SearchLoadingSkeleton` (12 cells, smaller posters).
public struct SearchLoadingSkeleton: View {
  private let count: Int

  public init(count: Int = 12) {
    self.count = count
  }

  public var body: some View {
    PosterGridSkeleton(count: count, minItemWidth: 100, spacing: PosterGridMetrics.spacing)
  }
}

#Preview("PosterGridSkeleton") {
  ScrollView { PosterGridSkeleton().padding() }
    .background(DesignTheme.background)
}
```

- [ ] **Step 2: Fill the gallery skeleton section**

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

### Task 9: Empty & error states

Reusable empty- and error-state components, mirroring the web `EmptyState` (icon + title + optional description + optional action) and `ErrorState` / `SearchErrorState` (icon + message + Retry). Thin wrappers over `ContentUnavailableView`, themed with the destructive token.

**Files:**
- Create: `Packages/DesignSystem/Sources/DesignSystem/StateViews.swift`
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift` (fill `statesSection`)

**Interfaces:**
- Consumes: SwiftUI `ContentUnavailableView`; `DesignTheme`.
- Produces:
  - `struct EmptyStateView: View` with `init(title: String, systemImage: String, description: String? = nil)`.
  - `struct ErrorStateView: View` with `init(message: String, retry: @escaping () -> Void)`.

- [ ] **Step 1: Write the state views**

Create `Packages/DesignSystem/Sources/DesignSystem/StateViews.swift`:

```swift
import SwiftUI

/// A centered empty state — icon + title + optional description. Mirrors the web
/// `EmptyState`. Built on `ContentUnavailableView` for the modern idiom.
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

/// A centered error state with a Retry action, mirroring the web `ErrorState`
/// (`AlertCircle` in the destructive colour + "Try Again").
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
        .foregroundStyle(DesignTheme.destructive)
    } description: {
      Text(message)
    } actions: {
      Button("Try Again", action: retry)
        .buttonStyle(.borderedProminent)
        .tint(DesignTheme.movie)
    }
  }
}

#Preview("States") {
  VStack {
    EmptyStateView(
      title: "No movies available",
      systemImage: "film",
      description: "Movies with files will appear here")
    ErrorStateView(message: "Failed to search") {}
  }
  .background(DesignTheme.background)
}
```

- [ ] **Step 2: Fill the gallery states section**

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
        description: "Movies with files will appear here")
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

### Task 10: Brand — logo mark + gradient wordmark

The SlipStream brand mark — a rounded square filled with the media gradient + "SS" monogram (web logo) — and the gradient wordmark ("SlipStream" with the media gradient as `foregroundStyle`).

**Files:**
- Create: `Packages/DesignSystem/Sources/DesignSystem/Brand.swift`
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift` (fill `brandSection`)

**Interfaces:**
- Consumes: `DesignTheme.mediaGradient`, `Font.ssSection`; `.glow(_:)` (Task 6).
- Produces:
  - `struct SlipStreamLogoMark: View` with `init(size: CGFloat = 40)`.
  - `struct SlipStreamWordmark: View` with `init()`.

- [ ] **Step 1: Write the brand views**

Create `Packages/DesignSystem/Sources/DesignSystem/Brand.swift`:

```swift
import SwiftUI

/// The SlipStream logo mark — a rounded square filled with the media gradient and
/// a white "SS" monogram, with a soft glow (web `bg-media-gradient glow-media-sm`).
public struct SlipStreamLogoMark: View {
  private let size: CGFloat

  public init(size: CGFloat = 40) {
    self.size = size
  }

  public var body: some View {
    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
      .fill(DesignTheme.mediaGradient)
      .frame(width: size, height: size)
      .overlay {
        Text("SS")
          .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
      }
      .glow(DesignTheme.movie, radius: size * 0.18)
  }
}

/// The "SlipStream" wordmark with the media gradient as its fill
/// (web `text-media-gradient`).
public struct SlipStreamWordmark: View {
  public init() {}

  public var body: some View {
    Text("SlipStream")
      .font(.ssSection)
      .foregroundStyle(DesignTheme.mediaGradient)
  }
}

#Preview("Brand") {
  HStack(spacing: 12) {
    SlipStreamLogoMark()
    SlipStreamWordmark()
  }
  .padding()
  .background(DesignTheme.background)
}
```

- [ ] **Step 2: Fill the gallery brand section**

In `DesignSystemGalleryView.swift`, replace:

```swift
  @ViewBuilder private var brandSection: some View { EmptyView() }
```

with:

```swift
  @ViewBuilder private var brandSection: some View {
    Section("Brand") {
      HStack(spacing: 12) {
        SlipStreamLogoMark()
        SlipStreamWordmark()
      }
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
git add Packages/DesignSystem/Sources/DesignSystem/Brand.swift \
        Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift
git commit -m "feat(ds): add SlipStream logo mark + gradient wordmark"
```

---

### Task 11: Status palette + StatusBadge

The request-status colour/icon mapping and a pill badge, mirroring `web/src/lib/request-status-config.tsx`. Maps the existing `RequestStatus` (Kit) — no new enum.

**Files:**
- Create: `Packages/DesignSystem/Sources/DesignSystem/StatusPalette.swift`
- Modify: `Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift` (fill `statusSection`)

**Interfaces:**
- Consumes: `RequestStatus` (Kit, 8 cases); `Color(hex:)` (Task 4); `Font.ssBadge`, `RadiusScale.pill`.
- Produces:
  - `extension RequestStatus { var statusColor: Color; var statusSymbol: String; var statusLabel: String }`
  - `struct StatusBadge: View` with `init(_ status: RequestStatus)`.

- [ ] **Step 1: Write the status palette + badge**

Create `Packages/DesignSystem/Sources/DesignSystem/StatusPalette.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// Request-status presentation, mirroring `web/src/lib/request-status-config.tsx`.
/// Colours are the web's Tailwind status hues; icons are SF Symbol analogues of
/// the web's lucide icons.
extension RequestStatus {
  public var statusColor: Color {
    switch self {
    case .pending: Color(hex: 0xEAB308)      // yellow-500
    case .approved: Color(hex: 0x3B82F6)     // blue-500
    case .searching: Color(hex: 0x3B82F6)    // blue-500
    case .downloading: Color(hex: 0xA855F7)  // purple-500
    case .available: Color(hex: 0x22C55E)    // green-500
    case .denied: Color(hex: 0xEF4444)       // red-500
    case .failed: Color(hex: 0xB91C1C)       // red-700
    case .cancelled: Color(hex: 0x6B7280)    // gray-500
    }
  }

  public var statusSymbol: String {
    switch self {
    case .pending: "clock"
    case .approved: "checkmark.circle"
    case .searching: "arrow.triangle.2.circlepath"
    case .downloading: "arrow.down.circle"
    case .available: "checkmark.circle.fill"
    case .denied: "xmark.circle"
    case .failed: "xmark.octagon"
    case .cancelled: "xmark.circle"
    }
  }

  public var statusLabel: String {
    switch self {
    case .pending: "Pending"
    case .approved: "Approved"
    case .searching: "Searching"
    case .downloading: "Downloading"
    case .available: "Available"
    case .denied: "Denied"
    case .failed: "Failed"
    case .cancelled: "Cancelled"
    }
  }
}

/// A pill status badge — coloured fill, white icon + label — mirroring the web
/// poster/request status badges (`rounded-4xl`, `text-white`).
public struct StatusBadge: View {
  private let status: RequestStatus

  public init(_ status: RequestStatus) {
    self.status = status
  }

  public var body: some View {
    HStack(spacing: 4) {
      Image(systemName: status.statusSymbol)
      Text(status.statusLabel)
    }
    .font(.ssBadge)
    .foregroundStyle(.white)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(status.statusColor, in: RoundedRectangle(cornerRadius: RadiusScale.pill, style: .continuous))
  }
}

#Preview("StatusBadge") {
  VStack(alignment: .leading, spacing: 8) {
    ForEach(RequestStatus.allCases, id: \.self) { StatusBadge($0) }
  }
  .padding()
  .background(DesignTheme.background)
}
```

- [ ] **Step 2: Fill the gallery status section**

In `DesignSystemGalleryView.swift`, replace:

```swift
  @ViewBuilder private var statusSection: some View { EmptyView() }
```

with:

```swift
  @ViewBuilder private var statusSection: some View {
    Section("Status palette") {
      ForEach(RequestStatus.allCases, id: \.self) { status in
        StatusBadge(status)
      }
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

Expected: `BUILD SUCCEEDED`. (`RequestStatus` is `CaseIterable`, so `allCases` lists all 8.)

- [ ] **Step 4: Commit**

```bash
git add Packages/DesignSystem/Sources/DesignSystem/StatusPalette.swift \
        Packages/DesignSystem/Sources/DesignSystem/DesignSystemGalleryView.swift
git commit -m "feat(ds): add request-status palette + StatusBadge"
```

---

### Task 12: End-to-end verification + tracker

Verify the whole gallery on iPhone and iPad, confirm the headless suite is green, and mark F1.7 done.

**Files:**
- Modify: `docs/TRACKER.md`

- [ ] **Step 1: Build, run, and screenshot on iPhone**

```
mcp__xcodebuildmcp__build_run_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Then `tap` the floating swatch button, `snapshot_ui` / `screenshot`, and scroll the gallery. Expected: a dark "Design System" sheet with **Theme** (swatches + gradient), **Typography (Inter)**, **PosterImage** (real poster + orange/blue fallbacks + a glowing cell), **PosterGrid + PosterSizeSlider** (slider reflows the grid — drag and confirm column count changes), **Skeletons** (pulsing+shimmering cells), **Empty / Error states**, **Brand** (gradient "SS" mark + wordmark), and **Status palette** (8 pill badges in the right colours).

- [ ] **Step 2: Confirm the adaptive grid on iPad**

```
mcp__xcodebuildmcp__build_run_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPad Pro 13-inch (M4)
```

Then open the gallery and `screenshot`. Expected: the poster grid shows more columns at the wider width, and the slider step is finer (10) — confirming the adaptive layout and mobile-aware step.

- [ ] **Step 3: Confirm the headless suite still passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (F1.4/F1.5/F1.6 plus the 12 added across Tasks 1–3).

- [ ] **Step 4: Mark F1.7 done in the tracker**

In `docs/TRACKER.md`, change the F1.7 line from `- [ ] **F1.7**` to `- [x] **F1.7**`:

```markdown
- [x] **F1.7** [Design system & image loading](superpowers/specs/01-foundations/design-system-image-loading.md) — Nuke posters, adaptive grid, skeletons
```

- [ ] **Step 5: Commit**

```bash
git add docs/TRACKER.md
git commit -m "docs: mark F1.7 (design system & visual identity) done"
```

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/01-foundations/design-system-image-loading.md`):
- Force-dark token layer (semantic + brand + gradient + radius) → Task 4 (`DesignTheme`, `Color(hex:)`) + Task 3 (`RadiusScale`). ✓
- Inter typography + ramp → Task 5. ✓
- Nuke cache + poster view → Task 4 (`PosterImagePipeline`) + Task 6 (`PosterImage`). ✓
- Adaptive grid + shared persisted poster-size preference (mobile-aware step, phone too) → Tasks 1–2 + Task 7. ✓
- Skeletons (pulse + shimmer) → Task 8 (using Task 6 modifiers). ✓
- Empty/error states → Task 9. ✓
- Brand (logo + gradient wordmark) + glow → Task 10 + Task 6 (`.glow`). ✓
- Status palette (8 `RequestStatus` cases) + StatusBadge → Task 11. ✓
- Surgical integration preserving F1.4/F1.5/F1.6 + force dark + shared preference injection + DEBUG gallery (no nested TabView) + cache-clear via `auth.state` → Task 4 (anchored edits). ✓
- Reuse `ModuleType` / `RequestStatus`, no `PosterKind` → Tasks 4, 6, 11. ✓
- Testing: headless Kit logic (Tasks 1–3) + on-device gallery on iPhone+iPad (Task 12). ✓

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N". Every code step shows complete code; the cross-task gallery file is edited via anchored stub-property replacements. The only runtime fetch (Inter font, Task 5 Step 1) has an explicit fallback. ✓

**3. Type consistency:** Names match across tasks — `PosterGridMetrics.{minSize,maxSize,defaultSize,compactStep,regularStep,spacing,clamp,step}`; `PosterSizeStoring.{loadPosterSize,savePosterSize}`; `PosterSizePreference(store:).{size,setSize}`; `RadiusScale.{small,base,pill}`; `TypeScale.{pageTitle,section,cardTitle,body,metadata,badge}`; `Color(hex:)`; `DesignTheme.{background,surface,foreground,muted,mutedForeground,accent,ring,destructive,border,movie,movieMuted,movieVibrant,tv,tvMuted,tvVibrant,mediaGradient,bootstrap}`; `ModuleType.{accentColor,fallbackSymbol}`; `PosterImagePipeline.{configure,clearImageCache}`; `Typography.{familyName,registerFonts}` + `Font.{ssPageTitle,ssSection,ssCardTitle,ssBody,ssMetadata,ssBadge}`; `.pulsing()`/`.shimmering()`/`.glow(_:)`; `PosterImage(url:module:cornerRadius:)`; `PosterGrid(items:minItemWidth:spacing:cell:)`; `PosterSizeSlider(preference:)`; `PosterCellSkeleton`/`PosterGridSkeleton`/`SearchLoadingSkeleton`; `EmptyStateView(title:systemImage:description:)`/`ErrorStateView(message:retry:)`; `SlipStreamLogoMark(size:)`/`SlipStreamWordmark()`; `RequestStatus.{statusColor,statusSymbol,statusLabel}` + `StatusBadge(_:)`; gallery sections `themeSection/typographySection/posterImageSection/posterGridSection/skeletonSection/statesSection/brandSection/statusSection`. `DesignTheme.bootstrap()` calls `PosterImagePipeline.configure()` (Task 4) then `Typography.registerFonts()` (Task 5). The app creates `PosterSizePreference(store: UserDefaultsPosterSizeStore())` the same way the gallery does. ✓

**Notes for the implementer:**
- Tasks 1–3 are headless (`cd Packages/SlipStreamKit && swift test`). Tasks 4–12 build via XcodeBuildMCP on `iPhone 17`; Task 12 also checks `iPad Pro 13-inch (M4)`.
- The pbxproj link (Task 4 Step 7) is four anchored edits, not the Xcode GUI — the IDs follow the existing `…0032`/`…0033` pattern. App-target edits (Task 4 Steps 8–9) are **anchored**, never whole-file, to preserve F1.4/F1.5/F1.6 wiring.
- Before merging to `main`, run `/code-review` per CLAUDE.md and squash-merge.
