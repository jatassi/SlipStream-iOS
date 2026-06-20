# App Shell & Navigation (F1.6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the signed-in `SignedInPlaceholderView` with a real, adaptive app shell — a four-destination navigation frame (Home, Search, Library, Settings) that renders a tab bar on iPhone and a sidebar on iPad/Mac from one SwiftUI layer, reserves a global downloads-strip slot, and keeps Sign Out reachable.

**Architecture:** Pure navigation state (the `AppTab` enum and an `@Observable NavigationModel`) lands in `SlipStreamKit` so it is unit-tested headlessly with `swift test`. The SwiftUI chrome lands in a new iOS-only `Feature-Shell` package: an `AppShellView` built on `TabView(selection:)` + `.tabViewStyle(.sidebarAdaptable)`, with each tab hosting its own `NavigationStack` (the seam later features push detail screens onto) and a top `safeAreaInset` reserving the downloads strip. The four tab destinations are deliberately thin placeholders — the real content (request list, search, library grid, settings) ships in its own feature plan and swaps in behind these names. The app composition root injects a shared `NavigationModel` alongside the existing `AuthStore`, and `RootView` routes the existing `AuthGateView`'s signed-in branch to `AppShellView`.

**Tech Stack:** Swift 6.2 (strict concurrency), SwiftUI, `@Observable` (Observation), Swift Package Manager (local path packages), Swift Testing, `TabView` `.sidebarAdaptable`, `NavigationStack`, `ContentUnavailableView`, XcodeBuildMCP for simulator build/run/snapshot.

## Global Constraints

- **Language/mode:** Swift 6.2, strict concurrency (`swift-tools-version: 6.2`). Every type crossing a concurrency boundary must be `Sendable`; UI/state types are `@MainActor`.
- **Deployment target:** iOS/iPadOS **26.0** minimum. `SlipStreamKit` additionally supports **macOS 14** *only* so its pure-logic tests run via `swift test`; `Feature-Shell` is **iOS-only** (matches the existing `Feature-Auth`).
- **One adaptive layer:** a single `TabView` + `.tabViewStyle(.sidebarAdaptable)` serves iPhone (compact → tab bar), iPad, and Mac (regular → sidebar). **Do not** branch on `UIDevice`/platform or build a second iPad-only layout.
- **Feature code in packages:** shell UI lives in `Packages/Feature-Shell`; navigation logic lives in `Packages/SlipStreamKit`. Keep `.xcodeproj` edits to the one required package-link.
- **Bundle id:** `dev.jatassi.slipstream` (unchanged).
- **Out of scope for F1.6 (placeholders only, owned by other plans):** the request list / Home content (F4.2), title search (F3.2), library poster grid (F3.1), the settings shell (F7.1), and the live downloads strip body (F5.1). This plan reserves their slots; it does **not** implement their content, networking, or polling.
- **Deliberately omitted chrome:** the notification bell (in-app inbox F6.1/F6.2 is **cut from v1**) and the passkey-promotion prompt (passkeys F8.1 are **deferred**, need paid-tier Associated Domains). Do not add either.
- **Commits:** frequent, one per task minimum.

## Resolved decisions (spec open questions, settled 2026-06-20)

The [spec](../specs/01-foundations/app-shell-navigation.md) left these open; resolved with the maintainer before writing this plan:

1. **Settings placement →** a **dedicated tab** (not a header gear button). With `.sidebarAdaptable` it appears in the iPhone tab bar and the iPad/Mac sidebar automatically.
2. **Search placement →** a **dedicated Search tab** with its own `.searchable` field (matches the spec's primary-destination list and the iOS media-app idiom). This sidesteps the web header's `isSearchPage || isLibraryPage && (…)` operator-precedence quirk entirely — iOS search has a stable home, not a per-screen-visibility conditional.
3. **Downloads strip placement →** a **persistent strip below each screen's header** (a top `safeAreaInset`), mirroring the web. F1.6 reserves the empty slot; F5.1 fills the body and gates it on active downloads.
4. **Adaptive container →** `TabView` + `.tabViewStyle(.sidebarAdaptable)` (the one-layer iOS 26 idiom), not a hand-rolled `NavigationSplitView` + size-class branch.

---

## File structure (this plan)

```
SlipStream-iOS/
  App/
    SlipStreamApp.swift                    # MODIFY: inject NavigationModel (Task 3)
    RootView.swift                         # MODIFY: AuthGateView { AppShellView() } (Task 3)
    SignedInPlaceholderView.swift          # DELETE: superseded by AppShellView (Task 3)
  Packages/
    SlipStreamKit/
      Sources/SlipStreamKit/Navigation/
        AppTab.swift                       # CREATE: top-level destinations (Task 1)
        NavigationModel.swift              # CREATE: @Observable selected-tab state (Task 1)
      Tests/SlipStreamKitTests/
        NavigationModelTests.swift         # CREATE: AppTab + NavigationModel tests (Task 1)
    Feature-Shell/                         # CREATE: new iOS-only UI package (Task 2)
      Package.swift
      Sources/FeatureShell/
        AppShellView.swift                 # the adaptive TabView shell
        DownloadsStrip.swift               # reserved strip slot (empty until F5.1)
        Tabs/HomePlaceholderView.swift
        Tabs/SearchPlaceholderView.swift
        Tabs/LibraryPlaceholderView.swift
        Tabs/SettingsPlaceholderView.swift # hosts Sign Out
```

**External dependencies:** none added. `Feature-Shell` depends only on the local `SlipStreamKit`.

**Build/test loops:**
- Task 1 uses the fast headless loop: `cd Packages/SlipStreamKit && swift test`.
- Tasks 2–3 use XcodeBuildMCP against `SlipStream.xcodeproj` / scheme `SlipStream`, simulators **iPhone 17** and **iPad Pro 13-inch (M5)** (CLAUDE.md lists M4; use whichever iPad Pro 13-inch is installed — confirm with `xcrun simctl list devices available`).

---

### Task 1: Navigation model (`AppTab` + `NavigationModel`)

The pure, headless-testable core of the shell: the enum of top-level destinations and the `@Observable` object that owns the selected tab. No SwiftUI — strings and state only — so it runs under `swift test` on the Mac host.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Navigation/AppTab.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Navigation/NavigationModel.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/NavigationModelTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable { case home, search, library, settings }` with `var id: String`, `var title: String`, `var systemImage: String`. `allCases` order is `[.home, .search, .library, .settings]`.
  - `@MainActor @Observable final class NavigationModel` with `init(selectedTab: AppTab = .home)`, `var selectedTab: AppTab`, and `func select(_ tab: AppTab)`.

- [ ] **Step 1: Write the failing tests**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/NavigationModelTests.swift`:

```swift
import Testing
@testable import SlipStreamKit

@Suite struct AppTabTests {
    @Test func allCasesAreHomeSearchLibrarySettingsInOrder() {
        #expect(AppTab.allCases == [.home, .search, .library, .settings])
    }

    @Test func eachTabHasANonEmptyTitleAndSymbol() {
        #expect(AppTab.home.title == "Home")
        #expect(AppTab.search.title == "Search")
        #expect(AppTab.library.title == "Library")
        #expect(AppTab.settings.title == "Settings")
        for tab in AppTab.allCases {
            #expect(!tab.title.isEmpty)
            #expect(!tab.systemImage.isEmpty)
            #expect(tab.id == tab.rawValue)
        }
    }
}

@MainActor
@Suite struct NavigationModelTests {
    @Test func defaultsToHome() {
        let nav = NavigationModel()
        #expect(nav.selectedTab == .home)
    }

    @Test func initWithExplicitTabIsHonored() {
        let nav = NavigationModel(selectedTab: .settings)
        #expect(nav.selectedTab == .settings)
    }

    @Test func selectChangesTheActiveTab() {
        let nav = NavigationModel()
        nav.select(.library)
        #expect(nav.selectedTab == .library)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'AppTab' in scope` / `cannot find 'NavigationModel' in scope`.

- [ ] **Step 3: Write `AppTab`**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Navigation/AppTab.swift`:

```swift
import Foundation

/// The portal's top-level destinations, mirroring the web portal's primary
/// navigation (Requests/Home, Search, Library, Settings). The `allCases` order
/// is the tab-bar / sidebar order.
public enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case search
    case library
    case settings

    public var id: String { rawValue }

    /// Human-readable tab label.
    public var title: String {
        switch self {
        case .home: "Home"
        case .search: "Search"
        case .library: "Library"
        case .settings: "Settings"
        }
    }

    /// SF Symbol name for the tab's icon.
    public var systemImage: String {
        switch self {
        case .home: "house"
        case .search: "magnifyingglass"
        case .library: "film"
        case .settings: "gearshape"
        }
    }
}
```

- [ ] **Step 4: Write `NavigationModel`**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Navigation/NavigationModel.swift`:

```swift
import Foundation
import Observation

/// App-wide navigation state for the signed-in shell. Owns the selected
/// top-level tab so features can switch tabs programmatically (e.g. a request
/// notification deep-links to Home). Detail screens are pushed onto each tab's
/// own `NavigationStack` by their owning features — this model holds only the
/// top-level selection.
@MainActor
@Observable
public final class NavigationModel {
    public var selectedTab: AppTab

    public init(selectedTab: AppTab = .home) {
        self.selectedTab = selectedTab
    }

    /// Switch the active top-level tab.
    public func select(_ tab: AppTab) {
        selectedTab = tab
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass — the 5 new tests plus the 11 existing auth tests (16 total), no failures.

- [ ] **Step 6: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Navigation Packages/SlipStreamKit/Tests/SlipStreamKitTests/NavigationModelTests.swift
git commit -m "feat(kit): add AppTab and NavigationModel for the app shell"
```

---

### Task 2: `Feature-Shell` package — the adaptive shell + placeholder tabs

Create the iOS-only UI package: the `AppShellView` (adaptive `TabView`), four placeholder tab destinations, and the reserved downloads-strip slot. Link it into the app target. The gate is a clean simulator build — the package compiles and links even though `RootView` doesn't render it until Task 3 (the same staged approach Plan 1 used for `Feature-Auth`).

**Files:**
- Create: `Packages/Feature-Shell/Package.swift`
- Create: `Packages/Feature-Shell/Sources/FeatureShell/DownloadsStrip.swift`
- Create: `Packages/Feature-Shell/Sources/FeatureShell/Tabs/HomePlaceholderView.swift`
- Create: `Packages/Feature-Shell/Sources/FeatureShell/Tabs/SearchPlaceholderView.swift`
- Create: `Packages/Feature-Shell/Sources/FeatureShell/Tabs/LibraryPlaceholderView.swift`
- Create: `Packages/Feature-Shell/Sources/FeatureShell/Tabs/SettingsPlaceholderView.swift`
- Create: `Packages/Feature-Shell/Sources/FeatureShell/AppShellView.swift`
- Modify (Xcode GUI): `SlipStream.xcodeproj` (add local package)

**Interfaces:**
- Consumes: `AppTab`, `NavigationModel` (Task 1); `AuthStore`, `AuthStore.State` (existing `SlipStreamKit`).
- Produces:
  - `public struct AppShellView: View` with `public init()`. Reads `@Environment(NavigationModel.self)`; its Settings tab reads `@Environment(AuthStore.self)`. Both must be injected by the caller (Task 3) before it is rendered.
  - Internal (package-private) `DownloadsStrip`, `HomePlaceholderView`, `SearchPlaceholderView`, `LibraryPlaceholderView`, `SettingsPlaceholderView`.

- [ ] **Step 1: Create the package manifest**

Create `Packages/Feature-Shell/Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FeatureShell",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "FeatureShell", targets: ["FeatureShell"]),
    ],
    dependencies: [
        .package(path: "../SlipStreamKit"),
    ],
    targets: [
        .target(
            name: "FeatureShell",
            dependencies: ["SlipStreamKit"]
        ),
    ]
)
```

- [ ] **Step 2: Create the downloads-strip slot**

Create `Packages/Feature-Shell/Sources/FeatureShell/DownloadsStrip.swift`:

```swift
import SwiftUI

/// Reserved slot for the global active-downloads strip (F5.1). The shell pins
/// this just below every tab's navigation bar. For F1.6 it renders nothing
/// (zero height), so the reserved `safeAreaInset` is invisible. F5.1 replaces
/// the body with the live, poll-fed strip, shown only when downloads are active.
struct DownloadsStrip: View {
    var body: some View {
        EmptyView()
    }
}
```

- [ ] **Step 3: Create the Home placeholder**

Create `Packages/Feature-Shell/Sources/FeatureShell/Tabs/HomePlaceholderView.swift`:

```swift
import SwiftUI

/// Placeholder for the Home tab. The request list (F4.2) replaces this.
struct HomePlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Home",
            systemImage: "house",
            description: Text("Your requests will appear here.")
        )
    }
}
```

- [ ] **Step 4: Create the Search placeholder**

Create `Packages/Feature-Shell/Sources/FeatureShell/Tabs/SearchPlaceholderView.swift`:

```swift
import SwiftUI

/// Placeholder for the Search tab. Title search (F3.2) replaces this. The
/// `.searchable` field establishes the search entry point now; results arrive
/// with F3.2.
struct SearchPlaceholderView: View {
    @State private var query = ""

    var body: some View {
        ContentUnavailableView(
            "Search",
            systemImage: "magnifyingglass",
            description: Text("Search movies and series.")
        )
        .searchable(text: $query, prompt: "Search movies and series")
    }
}
```

- [ ] **Step 5: Create the Library placeholder**

Create `Packages/Feature-Shell/Sources/FeatureShell/Tabs/LibraryPlaceholderView.swift`:

```swift
import SwiftUI

/// Placeholder for the Library tab. The poster grid (F3.1) replaces this.
struct LibraryPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Library",
            systemImage: "film",
            description: Text("Your in-library movies and series will appear here.")
        )
    }
}
```

- [ ] **Step 6: Create the Settings placeholder (hosts Sign Out)**

Create `Packages/Feature-Shell/Sources/FeatureShell/Tabs/SettingsPlaceholderView.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// Placeholder for the Settings tab. The settings shell (F7.1) replaces this.
/// Hosts Sign Out so the auth loop stays verifiable end-to-end until F7.1 lands
/// (it replaces the Sign Out that lived in the removed SignedInPlaceholderView).
struct SettingsPlaceholderView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        Form {
            if case let .signedIn(user) = auth.state {
                Section("Account") {
                    LabeledContent("Signed in as", value: user.username)
                }
            }
            Section {
                Button("Sign Out", role: .destructive) {
                    Task { await auth.signOut() }
                }
            }
        }
    }
}
```

- [ ] **Step 7: Create the adaptive shell**

Create `Packages/Feature-Shell/Sources/FeatureShell/AppShellView.swift`:

```swift
import SwiftUI
import SlipStreamKit

/// The signed-in app shell: an adaptive `TabView` that renders a tab bar on
/// iPhone (compact) and a sidebar on iPad / Mac (regular) via `.sidebarAdaptable`
/// — one layer for all three platforms. Each tab hosts its own `NavigationStack`
/// (so features can push detail screens) and reserves the global downloads-strip
/// slot just below the navigation bar.
public struct AppShellView: View {
    @Environment(NavigationModel.self) private var nav

    public init() {}

    public var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                tab(.home) { HomePlaceholderView() }
            }
            Tab(AppTab.search.title, systemImage: AppTab.search.systemImage, value: AppTab.search) {
                tab(.search) { SearchPlaceholderView() }
            }
            Tab(AppTab.library.title, systemImage: AppTab.library.systemImage, value: AppTab.library) {
                tab(.library) { LibraryPlaceholderView() }
            }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: AppTab.settings) {
                tab(.settings) { SettingsPlaceholderView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    /// Wraps a tab's content in its own navigation stack and reserves the
    /// downloads-strip slot below the navigation bar.
    @ViewBuilder
    private func tab<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .navigationTitle(tab.title)
                .safeAreaInset(edge: .top, spacing: 0) { DownloadsStrip() }
        }
    }
}
```

- [ ] **Step 8: Link `Feature-Shell` into the app target (Xcode GUI)**

In Xcode 26, open `SlipStream.xcodeproj`:
- File → Add Package Dependencies… → **Add Local…** → select `Packages/Feature-Shell` → Add Package.
- In the prompt, add the **`FeatureShell`** library product to the **`SlipStream`** app target.

(This is the one required `.xcodeproj` edit, mirroring how `Feature-Auth` was linked in Plan 1.)

- [ ] **Step 9: Build on the simulator to verify it compiles and links**

First confirm defaults, then build:

```
mcp__xcodebuildmcp__session_show_defaults
mcp__xcodebuildmcp__build_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED`. (The shell is compiled and linked but not yet shown — `RootView` still renders the placeholder until Task 3.)

- [ ] **Step 10: Commit**

```bash
git add Packages/Feature-Shell SlipStream.xcodeproj
git commit -m "feat(shell): add Feature-Shell adaptive TabView shell with placeholder tabs"
```

---

### Task 3: Wire the shell as the signed-in root and verify on iPhone + iPad

Inject the shared `NavigationModel`, route the auth gate's signed-in branch to `AppShellView`, remove the now-dead placeholder, and verify the adaptive layout on both a compact (iPhone) and a regular (iPad) device.

**Files:**
- Modify: `App/SlipStreamApp.swift`
- Modify: `App/RootView.swift`
- Delete: `App/SignedInPlaceholderView.swift`

**Interfaces:**
- Consumes: `AppShellView` (Task 2), `NavigationModel` (Task 1), `AuthGateView` (existing `FeatureAuth`), `AuthStore` (existing `SlipStreamKit`).
- Produces: the running, navigable shell (no downstream consumers in this plan).

- [ ] **Step 1: Inject `NavigationModel` in the app entry point**

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
    @State private var navigation = NavigationModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(navigation)
        }
    }
}
```

- [ ] **Step 2: Route the auth gate to the shell**

Replace `App/RootView.swift` with:

```swift
import SwiftUI
import FeatureAuth
import FeatureShell

struct RootView: View {
    var body: some View {
        AuthGateView {
            AppShellView()
        }
    }
}
```

- [ ] **Step 3: Delete the superseded placeholder**

```bash
git rm App/SignedInPlaceholderView.swift
```

(The shell's Settings tab now owns Sign Out, so `SignedInPlaceholderView` has no remaining references.)

- [ ] **Step 4: Build and run on iPhone, then verify the tab bar**

```
mcp__xcodebuildmcp__build_run_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPhone 17
```

Expected: `BUILD SUCCEEDED` and the app launches. After a brief "Unlocking…", it shows the **sign-in form** (signed-out state).

Sign in against the live instance to reach the shell (CLAUDE.md base URL `https://slipstream.atassi.org/`). On the simulator first set Features → Face ID → Enrolled. Enter the server URL, a real portal username, and its 4-digit PIN; tap Sign In. Then snapshot:

```
mcp__xcodebuildmcp__snapshot_ui
  simulatorName: iPhone 17
```

Expected: a **bottom tab bar with four tabs** — Home, Search, Library, Settings. Tapping each switches content (Home/Library/Search/Settings placeholders; the Search tab shows a search field). The Settings tab shows "Signed in as <username>" and a **Sign Out** button.

- [ ] **Step 5: Verify Sign Out returns to the sign-in form**

On the Settings tab, tap **Sign Out**. Expected: the app returns to the sign-in form (the auth gate's signed-out branch). This confirms the shell did not regress the auth loop.

- [ ] **Step 6: Build and run on iPad, then verify the sidebar (adaptivity)**

```
mcp__xcodebuildmcp__build_run_sim
  projectPath: ./SlipStream.xcodeproj
  scheme: SlipStream
  simulatorName: iPad Pro 13-inch (M5)
```

Sign in as in Step 4 (enroll Face ID on this simulator too), then:

```
mcp__xcodebuildmcp__snapshot_ui
  simulatorName: iPad Pro 13-inch (M5)
```

Expected: the **same four destinations render as a sidebar** (regular size class), not a bottom tab bar — proving the single `.sidebarAdaptable` layer adapts across compact and regular without any platform branch.

- [ ] **Step 7: Commit**

```bash
git add App/SlipStreamApp.swift App/RootView.swift
git commit -m "feat(app): route AuthGateView to the AppShellView shell"
```

---

## Self-Review

**1. Spec coverage** (against [`app-shell-navigation.md`](../specs/01-foundations/app-shell-navigation.md) "In scope"):
- Primary navigation across Home / Search / Library / Settings → Task 1 (`AppTab`) + Task 2 (`AppShellView` `TabView`). ✓
- Detail screens in the IA → each tab wraps content in a `NavigationStack` (Task 2 `tab(_:content:)`), the seam detail features (F3.3, F4.3) push onto. Detail *content* is out of scope (owned by those features). ✓ (noted, not silently dropped)
- Header chrome — global search entry → dedicated Search tab `.searchable` (Task 2 Step 4); settings entry → Settings tab (Task 2 Step 6); notification bell → **intentionally omitted** (inbox cut, per Global Constraints). ✓
- Hosts the downloads strip → reserved `safeAreaInset` slot + `DownloadsStrip` placeholder (Task 2 Steps 2, 7); passkey-promotion prompt → **intentionally omitted** (deferred F8.1). ✓
- Size-class adaptive, one layer (iPhone/iPad/Mac) → `.tabViewStyle(.sidebarAdaptable)`, verified on iPhone (tab bar) and iPad (sidebar) in Task 3 Steps 4 & 6. ✓
- Auth-guarded routing → the existing `AuthGateView` already gates; Task 3 routes its signed-in branch to the shell. ✓
- Spec open questions (settings tab-vs-button; per-screen search visibility) → resolved in "Resolved decisions". ✓

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N". Every code step shows complete, compilable code; every command states its expected output. The four tab *destinations* are intentional product placeholders (each names the feature that replaces it) — not plan placeholders. The one unavoidable manual step (Xcode "Add Local Package", Task 2 Step 8) mirrors Plan 1 and is explicitly justified. The end-to-end snapshot gate requires a live sign-in (CLAUDE.md instance), consistent with Plan 1's verification norm. ✓

**3. Type consistency:** Names match across tasks — `AppTab` cases (`home/search/library/settings`) and members (`title`, `systemImage`, `id`) are defined in Task 1 and used verbatim in Task 2's `Tab(...)` calls and the `tab(_:content:)` helper. `NavigationModel(selectedTab:)` / `.selectedTab` / `.select(_:)` are defined in Task 1, bound via `@Bindable` in Task 2's `AppShellView`, and injected in Task 3's `SlipStreamApp`. `AuthStore.State.signedIn(_:)` and `signOut()` match the existing `SlipStreamKit` API used by `SettingsPlaceholderView`. `AppShellView()` / `AuthGateView { … }` signatures match between Task 2 and Task 3. ✓
