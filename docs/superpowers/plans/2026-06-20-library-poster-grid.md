# F3.1 — Library Poster Grid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A two-sub-tab (Movies / Series) adaptive poster grid of the server's in-library titles, with persisted tab, shared poster size, loading/empty/error states, refresh-without-polling, and tap → a placeholder detail (F3.3 swaps the body later).

**Architecture:** Kit-side logic (`MediaAPI`, `LibraryTabStore`, `LibraryStore`) lives in `SlipStreamKit` and is headless-testable via `swift test`. A new iOS-only `Feature-Library` package holds the SwiftUI views (`LibraryView`, `MediaCard`, `MediaDetailStub`/`MediaDetailStubView`). The app composes one `LibraryStore` (mirroring `SystemStore`) and injects the library tab content into a now-generic `AppShellView`. No availability/state rendering (deferred to F3.4); no `PollStream` (refresh on appear / foreground / tab-reselect / pull).

**Tech Stack:** Swift 6.2, SwiftUI, iOS 26, swift-testing, Nuke (transitively via DesignSystem), XcodeBuildMCP for app builds.

## Global Constraints

- **Platforms:** iOS 26+ (`platforms: [.iOS(.v26)]`); kit also macOS so `swift test` runs headless.
- **Swift tools:** `swift-tools-version: 6.2`; Swift 6 language mode (strict concurrency).
- **Models are pure JSON mirrors** of `web/src/types/portal.ts` — do NOT add protocol conformances to `SlipStreamKit` model types for view convenience; presentation types live in `Feature-Library`.
- **Kit logic is headless-tested** (`swift test` in `Packages/SlipStreamKit`); iOS-only view/wiring code is verified by `build_sim` + an on-device run (the kit unit tests are the gate, per F1.5/F2.4 precedent).
- **Build via XcodeBuildMCP** (`mcp__xcodebuildmcp__build_sim` / `build_run_sim`) — never shell out to `xcodebuild`. `swift test` (SwiftPM) via Bash is fine for the kit.
- **No inline linter disables** — fix the code or the shared config.
- **Preserve prior wiring** (F1.4 `system.refresh()`, F1.5 `poller.resume()`/`setActivity`, F1.6 shell, F1.7 cache-clear, F2.4 `onUnauthorized`→`SessionExpiry`) — touch `RootView`/`SlipStreamApp`/`AppShellView` with **anchored edits only** (see memory `sdd-plan-file-replace-regression-hazard`).
- **Scheme:** `SlipStream`; **Simulator:** iPhone 17. Dev server creds Jackson/8472 (see `/test-with-dev-server`).

## File Structure

**Create (SlipStreamKit):**
- `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/MediaAPI.swift` — `MediaAPI` protocol.
- `Packages/SlipStreamKit/Sources/SlipStreamKit/Library/LibraryTab.swift` — `LibraryTab` enum + `LibraryTabStore` protocol + `UserDefaultsLibraryTabStore`.
- `Packages/SlipStreamKit/Sources/SlipStreamKit/Library/LibraryStore.swift` — `@MainActor @Observable LibraryStore`.

**Modify (SlipStreamKit):**
- `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift` — add `extension PortalAPIClient: MediaAPI`.

**Create (SlipStreamKit tests):**
- `Tests/SlipStreamKitTests/LibraryTabStoreTests.swift`, `Tests/SlipStreamKitTests/LibraryStoreTests.swift`.

**Modify (SlipStreamKit tests):**
- `Tests/SlipStreamKitTests/PortalAPIClientTests.swift` — library path/decode cases.
- `Tests/SlipStreamKitTests/Fakes.swift` — `FakeMediaAPI`, `FakeLibraryTabStore`, `CallCounter`, `sampleMovie`, `sampleSeries`.

**Create (Feature-Library):**
- `Packages/Feature-Library/Package.swift`
- `Packages/Feature-Library/Sources/FeatureLibrary/LibraryView.swift`
- `Packages/Feature-Library/Sources/FeatureLibrary/MediaCard.swift`
- `Packages/Feature-Library/Sources/FeatureLibrary/MediaDetailStub.swift`

**Modify (app + shell):**
- `SlipStream.xcodeproj/project.pbxproj` — register `Feature-Library` + link `FeatureLibrary` to the app target (6 insertions).
- `Packages/Feature-Shell/Sources/FeatureShell/AppShellView.swift` — make generic over injected library content.
- `Packages/Feature-Shell/Sources/FeatureShell/Tabs/LibraryPlaceholderView.swift` — **delete**.
- `App/RootView.swift` — `import FeatureLibrary`; `AppShellView { LibraryView() }`.
- `App/SlipStreamApp.swift` — compose + inject `LibraryStore`.

---

### Task 1: `MediaAPI` — library movies/series endpoints

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/MediaAPI.swift`
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift` (append an extension after the `SystemAPI` extension)
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift`

**Interfaces:**
- Consumes: `PortalAPIClient.send(_:method:base:token:body:)`, `APIBase.portal`, models `PortalMovieSearchResult` / `PortalSeriesSearchResult` (existing in `Models/Search.swift`).
- Produces: `protocol MediaAPI: Sendable { func libraryMovies(token: String) async throws -> [PortalMovieSearchResult]; func librarySeries(token: String) async throws -> [PortalSeriesSearchResult] }` and its `PortalAPIClient` conformance. `LibraryStore` (Task 3) and `FakeMediaAPI` (Task 3) consume this.

- [ ] **Step 1: Write the failing tests** — add to `PortalAPIClientTests.swift` (inside the existing `@Suite(.serialized) struct PortalAPIClientTests`):

```swift
@Test func libraryMoviesHitsPortalPathWithBearerAndDecodes() async throws {
  StubURLProtocol.handler = { request in
    #expect(request.url?.path == "/api/v1/requests/library/movies")
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
    let body = """
      [{"id":1,"tmdbId":603,"title":"The Matrix","year":1999,
        "overview":"o","posterUrl":"https://x/p.jpg","backdropUrl":null}]
      """
    let resp = HTTPURLResponse(
      url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    return (resp, Data(body.utf8))
  }
  let movies = try await client().libraryMovies(token: "tok")
  #expect(movies.count == 1)
  #expect(movies.first?.title == "The Matrix")
  #expect(movies.first?.tmdbId == 603)
}

@Test func librarySeriesHitsPortalPathWithBearerAndDecodes() async throws {
  StubURLProtocol.handler = { request in
    #expect(request.url?.path == "/api/v1/requests/library/series")
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
    let body = """
      [{"id":2,"tmdbId":1399,"tvdbId":121361,"title":"Game of Thrones","year":2011,
        "overview":"o","posterUrl":null,"backdropUrl":null,"network":"HBO"}]
      """
    let resp = HTTPURLResponse(
      url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    return (resp, Data(body.utf8))
  }
  let series = try await client().librarySeries(token: "tok")
  #expect(series.count == 1)
  #expect(series.first?.title == "Game of Thrones")
  #expect(series.first?.tvdbId == 121361)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test --filter PortalAPIClientTests`
Expected: FAIL — `value of type 'PortalAPIClient' has no member 'libraryMovies'`.

- [ ] **Step 3: Create the protocol** — `MediaAPI.swift`:

```swift
/// The in-library browse surface `LibraryStore` depends on. Backed by `PortalAPIClient`;
/// faked in tests. Both calls hit the token-scoped portal base (`GET /api/v1/requests/library/*`)
/// and return the full library in one payload (no pagination).
public protocol MediaAPI: Sendable {
  func libraryMovies(token: String) async throws -> [PortalMovieSearchResult]
  func librarySeries(token: String) async throws -> [PortalSeriesSearchResult]
}
```

- [ ] **Step 4: Add the conformance** — append to `PortalAPIClient.swift` after the `extension PortalAPIClient: SystemAPI { ... }` block:

```swift
extension PortalAPIClient: MediaAPI {
  public func libraryMovies(token: String) async throws -> [PortalMovieSearchResult] {
    try await send("library/movies", base: .portal, token: token)
  }

  public func librarySeries(token: String) async throws -> [PortalSeriesSearchResult] {
    try await send("library/series", base: .portal, token: token)
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test --filter PortalAPIClientTests`
Expected: PASS (all cases, including the two new ones).

- [ ] **Step 6: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/MediaAPI.swift \
        Packages/SlipStreamKit/Sources/SlipStreamKit/Networking/PortalAPIClient.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/PortalAPIClientTests.swift
git commit -m "feat(kit): MediaAPI library movies/series endpoints (F3.1)"
```

---

### Task 2: `LibraryTab` + `LibraryTabStore`

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Library/LibraryTab.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/LibraryTabStoreTests.swift`

**Interfaces:**
- Produces:
  - `enum LibraryTab: String, CaseIterable, Identifiable, Hashable, Sendable { case movies, series; var id: String; var title: String }`
  - `protocol LibraryTabStore: Sendable { var selectedTab: LibraryTab { get }; func setSelectedTab(_ tab: LibraryTab) }`
  - `final class UserDefaultsLibraryTabStore: LibraryTabStore` (key `"slipstream.libraryTab"`, default `.movies`).
- Consumed by `LibraryStore` (Task 3) and `LibraryView` (Task 4).

- [ ] **Step 1: Write the failing test** — `LibraryTabStoreTests.swift`:

```swift
import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct LibraryTabStoreTests {
  private func makeDefaults() -> UserDefaults {
    let suite = "test.library.tab.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }

  @Test func defaultsToMoviesWhenUnset() {
    let store = UserDefaultsLibraryTabStore(defaults: makeDefaults())
    #expect(store.selectedTab == .movies)
  }

  @Test func persistsAndRestoresSelectedTab() {
    let defaults = makeDefaults()
    let store = UserDefaultsLibraryTabStore(defaults: defaults)
    store.setSelectedTab(.series)
    #expect(store.selectedTab == .series)
    // A fresh instance over the same defaults restores it.
    let restored = UserDefaultsLibraryTabStore(defaults: defaults)
    #expect(restored.selectedTab == .series)
  }

  @Test func fallsBackToMoviesOnUnrecognisedValue() {
    let defaults = makeDefaults()
    defaults.set("garbage", forKey: "slipstream.libraryTab")
    let store = UserDefaultsLibraryTabStore(defaults: defaults)
    #expect(store.selectedTab == .movies)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test --filter LibraryTabStoreTests`
Expected: FAIL — `cannot find 'UserDefaultsLibraryTabStore' in scope`.

- [ ] **Step 3: Write the implementation** — `LibraryTab.swift`:

```swift
import Foundation

/// The two media sub-tabs of the library browse surface.
public enum LibraryTab: String, CaseIterable, Identifiable, Hashable, Sendable {
  case movies
  case series

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .movies: "Movies"
    case .series: "Series"
    }
  }
}

/// Non-secret persistence of the last-selected library sub-tab. Defaults to `.movies`.
public protocol LibraryTabStore: Sendable {
  var selectedTab: LibraryTab { get }
  func setSelectedTab(_ tab: LibraryTab)
}

public final class UserDefaultsLibraryTabStore: LibraryTabStore, @unchecked Sendable {
  private let defaults: UserDefaults
  private let key = "slipstream.libraryTab"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public var selectedTab: LibraryTab {
    defaults.string(forKey: key).flatMap(LibraryTab.init(rawValue:)) ?? .movies
  }

  public func setSelectedTab(_ tab: LibraryTab) {
    defaults.set(tab.rawValue, forKey: key)
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/SlipStreamKit && swift test --filter LibraryTabStoreTests`
Expected: PASS (3 cases).

- [ ] **Step 5: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Library/LibraryTab.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/LibraryTabStoreTests.swift
git commit -m "feat(kit): LibraryTab + persisted LibraryTabStore (F3.1)"
```

---

### Task 3: `LibraryStore`

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Library/LibraryStore.swift`
- Modify: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/Fakes.swift` (add `FakeMediaAPI`, `FakeLibraryTabStore`, `CallCounter`, `sampleMovie`, `sampleSeries`)
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/LibraryStoreTests.swift`

**Interfaces:**
- Consumes: `MediaAPI` (Task 1), `LibraryTab` / `LibraryTabStore` (Task 2), `ServerConfigStore`, `PortalMovieSearchResult` / `PortalSeriesSearchResult`, `APIClientError`.
- Produces:
  - `enum LibraryStore.LoadState: Equatable { case idle, loading, loaded, failed(String) }`
  - `LibraryStore` with: `init(makeMediaAPI: @escaping @Sendable (URL) -> MediaAPI, serverConfig: ServerConfigStore, tokenProvider: @escaping @MainActor () -> String?, tabStore: LibraryTabStore)`; `var selectedTab: LibraryTab { get set }`; `private(set) var movies/series`; `private(set) var moviesState/seriesState`; `func state(for: LibraryTab) -> LoadState`; `func loadIfNeeded(_:) async`; `func refresh(_:) async`. Consumed by `LibraryView` (Task 4) and the app (Task 4).

- [ ] **Step 1: Add the test doubles** — append to `Fakes.swift`:

```swift
struct FakeMediaAPI: MediaAPI {
  var onMovies: @Sendable (String) async throws -> [PortalMovieSearchResult] = { _ in [] }
  var onSeries: @Sendable (String) async throws -> [PortalSeriesSearchResult] = { _ in [] }
  func libraryMovies(token: String) async throws -> [PortalMovieSearchResult] {
    try await onMovies(token)
  }
  func librarySeries(token: String) async throws -> [PortalSeriesSearchResult] {
    try await onSeries(token)
  }
}

final class FakeLibraryTabStore: LibraryTabStore, @unchecked Sendable {
  private var tab: LibraryTab
  private(set) var setCount = 0
  init(tab: LibraryTab = .movies) { self.tab = tab }
  var selectedTab: LibraryTab { tab }
  func setSelectedTab(_ tab: LibraryTab) {
    self.tab = tab
    setCount += 1
  }
}

/// Thread-safe call counter for asserting fetch counts from `@Sendable` fake closures.
final class CallCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0
  var count: Int { lock.withLock { value } }
  func increment() { lock.withLock { value += 1 } }
}

func sampleMovie(id: Int = 1, title: String = "The Matrix") -> PortalMovieSearchResult {
  PortalMovieSearchResult(id: id, tmdbId: 603, title: title, year: 1999)
}

func sampleSeries(id: Int = 2, title: String = "Game of Thrones") -> PortalSeriesSearchResult {
  PortalSeriesSearchResult(id: id, tmdbId: 1399, title: title, tvdbId: 121_361, year: 2011)
}
```

(`NSLock.withLock` needs `import Foundation`, already at the top of `Fakes.swift`.)

- [ ] **Step 2: Write the failing tests** — `LibraryStoreTests.swift`:

```swift
import Foundation
import Testing

@testable import SlipStreamKit

@MainActor
@Suite struct LibraryStoreTests {
  let serverURL = URL(string: "https://slipstream.example.com")!

  private func makeStore(
    api: FakeMediaAPI,
    config: FakeServerConfigStore? = nil,
    token: String? = "tok",
    tabStore: FakeLibraryTabStore = FakeLibraryTabStore()
  ) -> LibraryStore {
    LibraryStore(
      makeMediaAPI: { _ in api },
      serverConfig: config ?? FakeServerConfigStore(url: serverURL),
      tokenProvider: { token },
      tabStore: tabStore
    )
  }

  @Test func loadIfNeededPopulatesMoviesAndMarksLoaded() async {
    let api = FakeMediaAPI(onMovies: { _ in [sampleMovie(), sampleMovie(id: 9, title: "Heat")] })
    let store = makeStore(api: api)

    await store.loadIfNeeded(.movies)

    #expect(store.movies.count == 2)
    #expect(store.state(for: .movies) == .loaded)
  }

  @Test func emptyPayloadMarksLoadedWithNoItems() async {
    let store = makeStore(api: FakeMediaAPI(onMovies: { _ in [] }))
    await store.loadIfNeeded(.movies)
    #expect(store.movies.isEmpty)
    #expect(store.state(for: .movies) == .loaded)
  }

  @Test func failureMarksFailedWithMessage() async {
    let api = FakeMediaAPI(onMovies: { _ in
      throw APIClientError.http(status: 500, message: "boom", error: nil)
    })
    let store = makeStore(api: api)

    await store.loadIfNeeded(.movies)

    #expect(store.state(for: .movies) == .failed("boom"))
    #expect(store.movies.isEmpty)
  }

  @Test func loadIfNeededIsLazyPerTab() async {
    let api = FakeMediaAPI(
      onMovies: { _ in [sampleMovie()] },
      onSeries: { _ in
        Issue.record("series must not be fetched when only movies is requested")
        return []
      })
    let store = makeStore(api: api)
    await store.loadIfNeeded(.movies)
    #expect(store.state(for: .series) == .idle)
  }

  @Test func loadIfNeededSkipsWhenAlreadyLoaded() async {
    let counter = CallCounter()
    let api = FakeMediaAPI(onMovies: { _ in counter.increment(); return [sampleMovie()] })
    let store = makeStore(api: api)

    await store.loadIfNeeded(.movies)
    await store.loadIfNeeded(.movies)

    #expect(counter.count == 1)
  }

  @Test func refreshReFetchesEvenWhenLoaded() async {
    let counter = CallCounter()
    let api = FakeMediaAPI(onMovies: { _ in counter.increment(); return [sampleMovie()] })
    let store = makeStore(api: api)

    await store.loadIfNeeded(.movies)
    await store.refresh(.movies)

    #expect(counter.count == 2)
  }

  @Test func loadIfNeededRetriesAfterFailure() async {
    let counter = CallCounter()
    let api = FakeMediaAPI(onMovies: { _ in
      counter.increment()
      throw APIClientError.transport("offline")
    })
    let store = makeStore(api: api)

    await store.loadIfNeeded(.movies)  // fails
    await store.loadIfNeeded(.movies)  // failed state is retryable, so this fetches again

    #expect(counter.count == 2)
  }

  @Test func selectedTabSetterPersists() {
    let tabStore = FakeLibraryTabStore(tab: .movies)
    let store = makeStore(api: FakeMediaAPI(), tabStore: tabStore)

    store.selectedTab = .series

    #expect(store.selectedTab == .series)
    #expect(tabStore.selectedTab == .series)
    #expect(tabStore.setCount == 1)
  }

  @Test func selectedTabInitialisesFromStore() {
    let store = makeStore(api: FakeMediaAPI(), tabStore: FakeLibraryTabStore(tab: .series))
    #expect(store.selectedTab == .series)
  }

  @Test func loadIsNoOpWithoutToken() async {
    let api = FakeMediaAPI(onMovies: { _ in
      Issue.record("must not fetch without a token")
      return []
    })
    let store = makeStore(api: api, token: nil)
    await store.loadIfNeeded(.movies)
    #expect(store.state(for: .movies) == .idle)
  }

  @Test func loadIsNoOpWithoutBaseURL() async {
    let api = FakeMediaAPI(onMovies: { _ in
      Issue.record("must not fetch without a base URL")
      return []
    })
    let store = makeStore(api: api, config: FakeServerConfigStore(url: nil))
    await store.loadIfNeeded(.movies)
    #expect(store.state(for: .movies) == .idle)
  }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd Packages/SlipStreamKit && swift test --filter LibraryStoreTests`
Expected: FAIL — `cannot find 'LibraryStore' in scope`.

- [ ] **Step 4: Write the implementation** — `LibraryStore.swift`:

```swift
import Foundation
import Observation

/// Owns the in-library browse surface: per-tab arrays of movies / series and their
/// load states. Tabs load lazily (a tab fetches on first appearance or after a failure)
/// and are refreshed explicitly (pull / foreground / tab re-selection) — there is no
/// background poll, mirroring the web's staleness-based refetch. The selected tab is
/// persisted through `LibraryTabStore`. Availability is decoded but not surfaced here;
/// per-card state is F3.4's concern.
@MainActor
@Observable
public final class LibraryStore {
  public enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
  }

  public private(set) var movies: [PortalMovieSearchResult] = []
  public private(set) var series: [PortalSeriesSearchResult] = []
  public private(set) var moviesState: LoadState = .idle
  public private(set) var seriesState: LoadState = .idle

  /// The selected sub-tab. Reads/writes persist through `LibraryTabStore`.
  public var selectedTab: LibraryTab {
    didSet { tabStore.setSelectedTab(selectedTab) }
  }

  private let makeMediaAPI: @Sendable (URL) -> MediaAPI
  private let serverConfig: ServerConfigStore
  private let tokenProvider: @MainActor () -> String?
  private let tabStore: LibraryTabStore

  public init(
    makeMediaAPI: @escaping @Sendable (URL) -> MediaAPI,
    serverConfig: ServerConfigStore,
    tokenProvider: @escaping @MainActor () -> String?,
    tabStore: LibraryTabStore
  ) {
    self.makeMediaAPI = makeMediaAPI
    self.serverConfig = serverConfig
    self.tokenProvider = tokenProvider
    self.tabStore = tabStore
    self.selectedTab = tabStore.selectedTab
  }

  public func state(for tab: LibraryTab) -> LoadState {
    switch tab {
    case .movies: moviesState
    case .series: seriesState
    }
  }

  /// Fetch a tab only if it has never loaded or previously failed; a no-op while loading
  /// or already loaded. Call from `.task`/`.onChange(selectedTab)`.
  public func loadIfNeeded(_ tab: LibraryTab) async {
    switch state(for: tab) {
    case .idle, .failed: await load(tab)
    case .loading, .loaded: break
    }
  }

  /// Force a fetch (pull-to-refresh, foreground, retry), regardless of current state.
  public func refresh(_ tab: LibraryTab) async {
    await load(tab)
  }

  private func load(_ tab: LibraryTab) async {
    guard let url = serverConfig.baseURL, let token = tokenProvider() else { return }
    setState(.loading, for: tab)
    let api = makeMediaAPI(url)
    do {
      switch tab {
      case .movies: movies = try await api.libraryMovies(token: token)
      case .series: series = try await api.librarySeries(token: token)
      }
      setState(.loaded, for: tab)
    } catch let error as APIClientError {
      setState(.failed(Self.message(for: error)), for: tab)
    } catch {
      setState(.failed(error.localizedDescription), for: tab)
    }
  }

  private func setState(_ state: LoadState, for tab: LibraryTab) {
    switch tab {
    case .movies: moviesState = state
    case .series: seriesState = state
    }
  }

  private static func message(for error: APIClientError) -> String {
    switch error {
    case let .http(status, message, _): message ?? "Request failed (\(status))."
    case .decoding: "Couldn't read the library response."
    case let .transport(detail): detail
    }
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test --filter LibraryStoreTests`
Expected: PASS (11 cases).

- [ ] **Step 6: Run the whole kit suite (no regressions)**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: PASS (all suites green).

- [ ] **Step 7: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Library/LibraryStore.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/Fakes.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/LibraryStoreTests.swift
git commit -m "feat(kit): LibraryStore — lazy per-tab load, refresh, persisted tab (F3.1)"
```

---

### Task 4: `Feature-Library` package, `LibraryView` grid, and app wiring

This is the integration task: it creates the iOS view package, the grid UI, and links everything into the app. Verified by a successful `build_sim` and an on-device run showing the grid against the dev server. (Tap → detail is Task 5; cards are non-interactive here.)

**Files:**
- Create: `Packages/Feature-Library/Package.swift`
- Create: `Packages/Feature-Library/Sources/FeatureLibrary/MediaCard.swift`
- Create: `Packages/Feature-Library/Sources/FeatureLibrary/LibraryView.swift`
- Modify: `SlipStream.xcodeproj/project.pbxproj` (6 insertions)
- Modify: `Packages/Feature-Shell/Sources/FeatureShell/AppShellView.swift`
- Delete: `Packages/Feature-Shell/Sources/FeatureShell/Tabs/LibraryPlaceholderView.swift`
- Modify: `App/RootView.swift`
- Modify: `App/SlipStreamApp.swift`

**Interfaces:**
- Consumes: `LibraryStore` (Task 3) via `@Environment`, `PosterSizePreference`, `LibraryTab`, DesignSystem (`PosterGrid`, `PosterImage`, `PosterGridSkeleton`, `EmptyStateView`, `ErrorStateView`, `PosterSizeSlider`, `DesignTheme`, `Font.ss*`), `ModuleType`.
- Produces: `public struct LibraryView: View { public init() }`; `AppShellView<LibraryContent: View>` with `public init(@ViewBuilder libraryContent:)`.

- [ ] **Step 1: Create `Feature-Library/Package.swift`**

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "FeatureLibrary",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "FeatureLibrary", targets: ["FeatureLibrary"])
  ],
  dependencies: [
    .package(path: "../SlipStreamKit"),
    .package(path: "../DesignSystem"),
  ],
  targets: [
    .target(
      name: "FeatureLibrary",
      dependencies: ["SlipStreamKit", "DesignSystem"]
    )
  ]
)
```

- [ ] **Step 2: Create `MediaCard.swift`**

```swift
import DesignSystem
import SlipStreamKit
import SwiftUI

/// One library poster cell: a 2:3 poster with the title and year below it. No
/// availability/state badges — that is F3.4's surface.
struct MediaCard: View {
  let posterURL: URL?
  let module: ModuleType
  let title: String
  let year: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      PosterImage(url: posterURL, module: module)
      Text(title)
        .font(.ssCardTitle)
        .foregroundStyle(DesignTheme.foreground)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
      Text(year.map(String.init) ?? "Unknown year")
        .font(.ssMetadata)
        .foregroundStyle(DesignTheme.mutedForeground)
    }
  }
}
```

- [ ] **Step 3: Create `LibraryView.swift`** (Task 4 version — non-interactive cards; Task 5 adds navigation)

```swift
import DesignSystem
import SlipStreamKit
import SwiftUI

/// The Library tab: Movies / Series sub-tabs over an adaptive poster grid of the
/// server's in-library titles. Tabs load lazily and refresh on appear / foreground /
/// re-selection / pull — no background poll. Reads the shared `LibraryStore` and
/// `PosterSizePreference` from the environment.
public struct LibraryView: View {
  @Environment(LibraryStore.self) private var store
  @Environment(PosterSizePreference.self) private var posterSize
  @Environment(\.scenePhase) private var scenePhase
  @State private var showingSizeControl = false

  public init() {}

  public var body: some View {
    @Bindable var store = store
    VStack(spacing: 0) {
      Picker("Library section", selection: $store.selectedTab) {
        ForEach(LibraryTab.allCases) { tab in
          Text(tab.title).tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)
      .padding(.bottom, 8)

      content
    }
    .refreshable { await store.refresh(store.selectedTab) }
    .task(id: store.selectedTab) { await store.loadIfNeeded(store.selectedTab) }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await store.refresh(store.selectedTab) } }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showingSizeControl = true
        } label: {
          Image(systemName: "rectangle.grid.3x2")
        }
        .accessibilityLabel("Poster size")
        .popover(isPresented: $showingSizeControl) {
          PosterSizeSlider(preference: posterSize)
            .frame(minWidth: 260)
            .padding()
            .presentationCompactAdaptation(.popover)
        }
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch store.state(for: store.selectedTab) {
    case .idle, .loading:
      ScrollView {
        PosterGridSkeleton(minItemWidth: posterSize.size).padding()
      }
    case .failed(let message):
      ErrorStateView(message: message) {
        Task { await store.refresh(store.selectedTab) }
      }
    case .loaded:
      loadedContent
    }
  }

  @ViewBuilder
  private var loadedContent: some View {
    switch store.selectedTab {
    case .movies:
      grid(
        items: store.movies,
        emptyTitle: "No movies available",
        emptyDescription: "Movies with files will appear here",
        card: { MediaCard(posterURL: url($0.posterUrl), module: .movie, title: $0.title, year: $0.year) })
    case .series:
      grid(
        items: store.series,
        emptyTitle: "No series available",
        emptyDescription: "Series with files will appear here",
        card: { MediaCard(posterURL: url($0.posterUrl), module: .tv, title: $0.title, year: $0.year) })
    }
  }

  @ViewBuilder
  private func grid<Item: Identifiable>(
    items: [Item],
    emptyTitle: String,
    emptyDescription: String,
    card: @escaping (Item) -> MediaCard
  ) -> some View {
    if items.isEmpty {
      EmptyStateView(
        title: emptyTitle,
        systemImage: store.selectedTab == .movies ? "film" : "tv",
        description: emptyDescription)
    } else {
      ScrollView {
        PosterGrid(items: items, minItemWidth: posterSize.size) { item in
          card(item)
        }
        .padding()
      }
    }
  }

  private func url(_ string: String?) -> URL? {
    string.flatMap(URL.init(string:))
  }
}
```

- [ ] **Step 4: Make `AppShellView` accept injected library content** — replace `AppShellView.swift` struct declaration and the library tab line. Apply these anchored edits:

Change the struct signature + add the stored property and init:

```swift
public struct AppShellView<LibraryContent: View>: View {
  @Environment(NavigationModel.self) private var nav
  private let libraryContent: () -> LibraryContent

  public init(@ViewBuilder libraryContent: @escaping () -> LibraryContent) {
    self.libraryContent = libraryContent
  }
```

Change the library `Tab` body from `LibraryPlaceholderView()` to the injected content:

```swift
      Tab(AppTab.library.title, systemImage: AppTab.library.systemImage, value: AppTab.library) {
        tab(.library) { libraryContent() }
      }
```

(Leave the Home / Search / Settings tabs and the private `tab(_:content:)` helper unchanged.)

- [ ] **Step 5: Delete the placeholder**

```bash
git rm Packages/Feature-Shell/Sources/FeatureShell/Tabs/LibraryPlaceholderView.swift
```

- [ ] **Step 6: Inject `LibraryView` in `RootView`** — add the import and pass the content. Anchored edits to `App/RootView.swift`:

Add `import FeatureLibrary` (keep the existing imports — alphabetical: it goes after `import FeatureAuth`):

```swift
import FeatureAuth
import FeatureLibrary
import FeatureShell
```

Change the `AppShellView()` call to inject the library content (keep the trailing `.onAppear`/`.task` modifiers exactly as they are):

```swift
      AppShellView {
        LibraryView()
      }
      // Re-enable polling on a fresh sign-in: a 401 auto-logout suspends the engine
      // (via SessionExpiry) and only resume() clears it. (F2.4)
      .onAppear { poller.resume() }
      // Refresh system discovery (enabled modules + portalEnabled) on the
      // signed-in path. F1.4 wiring; previously triggered by the removed
      // SignedInPlaceholderView. Downstream features (F2.6, F3.x) read this.
      .task { await system.refresh() }
```

- [ ] **Step 7: Compose and inject `LibraryStore` in `SlipStreamApp`** — anchored edits to `App/SlipStreamApp.swift`.

Add the stored property next to the others:

```swift
  @State private var library: LibraryStore
```

In `init()`, after the `initialSystem` block and before `let initialPoller`, add (the `tokenProvider` reads the just-created `initialAuth`; library calls carry a token so they route 401s through the same `onUnauthorized` → `SessionExpiry`):

```swift
    let initialLibrary = LibraryStore(
      makeMediaAPI: { url in PortalAPIClient(baseURL: url, onUnauthorized: onUnauthorized) },
      serverConfig: UserDefaultsServerConfigStore(),
      tokenProvider: { initialAuth.currentToken },
      tabStore: UserDefaultsLibraryTabStore()
    )
```

At the end of `init()` (next to `_auth`/`_system`/`_poller`), add:

```swift
    _library = State(initialValue: initialLibrary)
```

In `body`, add the environment injection (next to the other `.environment(...)` calls, before `.preferredColorScheme(.dark)`):

```swift
        .environment(library)
```

- [ ] **Step 8: Register `Feature-Library` in the Xcode project** — 6 insertions in `SlipStream.xcodeproj/project.pbxproj`, mirroring `DesignSystem` exactly (new IDs `…0041`/`…0042`/`…0043`).

(a) PBXBuildFile section — after the `DesignSystem in Frameworks` line (`…0031`):
```
		1A1A1A1A1A1A1A1A1A1A0041 /* FeatureLibrary in Frameworks */ = {isa = PBXBuildFile; productRef = 1A1A1A1A1A1A1A1A1A1A0043 /* FeatureLibrary */; };
```

(b) PBXFrameworksBuildPhase `files` list — after the `…0031 /* DesignSystem in Frameworks */,` line:
```
				1A1A1A1A1A1A1A1A1A1A0041 /* FeatureLibrary in Frameworks */,
```

(c) Target `packageProductDependencies` list — after the `…0033 /* DesignSystem */,` line:
```
				1A1A1A1A1A1A1A1A1A1A0043 /* FeatureLibrary */,
```

(d) PBXProject `packageReferences` list — after the `…0032 /* XCLocalSwiftPackageReference "Packages/DesignSystem" */,` line:
```
				1A1A1A1A1A1A1A1A1A1A0042 /* XCLocalSwiftPackageReference "Packages/Feature-Library" */,
```

(e) XCLocalSwiftPackageReference section — after the DesignSystem block (`…0032`):
```
		1A1A1A1A1A1A1A1A1A1A0042 /* XCLocalSwiftPackageReference "Packages/Feature-Library" */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = Packages/Feature-Library;
		};
```

(f) XCSwiftPackageProductDependency section — after the DesignSystem block (`…0033`):
```
		1A1A1A1A1A1A1A1A1A1A0043 /* FeatureLibrary */ = {
			isa = XCSwiftPackageProductDependency;
			productName = FeatureLibrary;
		};
```

- [ ] **Step 9: Build the app for the simulator**

Run: `mcp__xcodebuildmcp__build_sim` (scheme `SlipStream`, simulator `iPhone 17`).
Expected: BUILD SUCCEEDED. If it fails with "no such module 'FeatureLibrary'", the pbxproj insertions are inconsistent — re-check that all six IDs match and that `Packages/Feature-Library` resolves; clean (`mcp__xcodebuildmcp__clean`) and rebuild.

- [ ] **Step 10: Run on-device and verify the grid**

Use the `/test-with-dev-server` flow: `build_run_sim` on iPhone 17 against the `--dev-mode` server, sign in (Jackson/8472), open the **Library** tab.
Expected: a Movies/Series segmented control; a poster skeleton flash, then a grid of movie posters with titles+years (or the "No movies available" empty state). Switch to Series → its grid loads lazily. The poster-size toolbar button opens a slider that resizes the grid. Capture a screenshot.

- [ ] **Step 11: Commit**

```bash
git add Packages/Feature-Library App/RootView.swift App/SlipStreamApp.swift \
        Packages/Feature-Shell/Sources/FeatureShell/AppShellView.swift \
        SlipStream.xcodeproj/project.pbxproj
git rm --cached Packages/Feature-Shell/Sources/FeatureShell/Tabs/LibraryPlaceholderView.swift 2>/dev/null || true
git commit -m "feat(app): Library poster grid — Feature-Library package + shell wiring (F3.1)"
```

---

### Task 5: Tap → placeholder media detail

**Files:**
- Create: `Packages/Feature-Library/Sources/FeatureLibrary/MediaDetailStub.swift` (the `Hashable` nav value + its stub detail view)
- Modify: `Packages/Feature-Library/Sources/FeatureLibrary/LibraryView.swift` (wrap cards in `NavigationLink`, add `.navigationDestination`)

**Interfaces:**
- Consumes: `ModuleType`, `MediaCard`, DesignSystem (`PosterImage`, `DesignTheme`, `Font.ss*`), `PortalMovieSearchResult` / `PortalSeriesSearchResult`.
- Produces: `struct MediaDetailStub: Hashable, Sendable` with `init(movie:)` and `init(series:)`; `struct MediaDetailStubView: View`.

- [ ] **Step 1: Create `MediaDetailStub.swift`**

```swift
import DesignSystem
import SlipStreamKit
import SwiftUI

/// The navigation value for a tapped library poster. A small presentation type
/// (built from a movie or series at tap time) so the `SlipStreamKit` models stay
/// pure JSON mirrors. F3.3 replaces `MediaDetailStubView` with the real detail screen.
struct MediaDetailStub: Hashable, Sendable {
  let mediaId: Int
  let module: ModuleType
  let title: String
  let year: Int?
  let overview: String?
  let posterURL: URL?

  init(movie: PortalMovieSearchResult) {
    mediaId = movie.id
    module = .movie
    title = movie.title
    year = movie.year
    overview = movie.overview
    posterURL = movie.posterUrl.flatMap(URL.init(string:))
  }

  init(series: PortalSeriesSearchResult) {
    mediaId = series.id
    module = .tv
    title = series.title
    year = series.year
    overview = series.overview
    posterURL = series.posterUrl.flatMap(URL.init(string:))
  }
}

/// A lightweight placeholder detail rendered from data already in the library
/// payload. F3.3 (rich media detail, second `/metadata` base) replaces this body.
struct MediaDetailStubView: View {
  let stub: MediaDetailStub

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        PosterImage(url: stub.posterURL, module: stub.module)
          .frame(maxWidth: 200)
          .frame(maxWidth: .infinity, alignment: .center)

        Text(stub.title)
          .font(.ssPageTitle)
          .foregroundStyle(DesignTheme.foreground)

        if let year = stub.year {
          Text(String(year))
            .font(.ssBody)
            .foregroundStyle(DesignTheme.mutedForeground)
        }

        if let overview = stub.overview, !overview.isEmpty {
          Text(overview)
            .font(.ssBody)
            .foregroundStyle(DesignTheme.foreground)
        }

        Label("Full details coming soon", systemImage: "hammer")
          .font(.ssMetadata)
          .foregroundStyle(DesignTheme.mutedForeground)
          .padding(.top, 8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
    .navigationTitle(stub.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}
```

- [ ] **Step 2: Make cards navigate** — modify `LibraryView.swift`. Wrap the card in a `NavigationLink(value:)` inside the `grid(...)` cell, and add a `.navigationDestination` to the root `VStack`.

The `grid(...)` helper gains a `stub:` mapping parameter; replace the helper and both call sites:

```swift
  @ViewBuilder
  private func grid<Item: Identifiable>(
    items: [Item],
    emptyTitle: String,
    emptyDescription: String,
    card: @escaping (Item) -> MediaCard,
    stub: @escaping (Item) -> MediaDetailStub
  ) -> some View {
    if items.isEmpty {
      EmptyStateView(
        title: emptyTitle,
        systemImage: store.selectedTab == .movies ? "film" : "tv",
        description: emptyDescription)
    } else {
      ScrollView {
        PosterGrid(items: items, minItemWidth: posterSize.size) { item in
          NavigationLink(value: stub(item)) {
            card(item)
          }
          .buttonStyle(.plain)
        }
        .padding()
      }
    }
  }
```

Update `loadedContent` to pass `stub:`:

```swift
  @ViewBuilder
  private var loadedContent: some View {
    switch store.selectedTab {
    case .movies:
      grid(
        items: store.movies,
        emptyTitle: "No movies available",
        emptyDescription: "Movies with files will appear here",
        card: { MediaCard(posterURL: url($0.posterUrl), module: .movie, title: $0.title, year: $0.year) },
        stub: { MediaDetailStub(movie: $0) })
    case .series:
      grid(
        items: store.series,
        emptyTitle: "No series available",
        emptyDescription: "Series with files will appear here",
        card: { MediaCard(posterURL: url($0.posterUrl), module: .tv, title: $0.title, year: $0.year) },
        stub: { MediaDetailStub(series: $0) })
    }
  }
```

Add the destination to the root `VStack` in `body` — attach after `.refreshable { ... }`:

```swift
    .navigationDestination(for: MediaDetailStub.self) { stub in
      MediaDetailStubView(stub: stub)
    }
```

- [ ] **Step 3: Build the app**

Run: `mcp__xcodebuildmcp__build_sim` (scheme `SlipStream`, iPhone 17).
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Verify tap navigation on-device**

`build_run_sim` against the dev server, sign in, open Library, tap a poster.
Expected: pushes a detail screen showing the poster, title, year, overview, and a "Full details coming soon" line; the back button returns to the grid. Tab/selection and scroll position are preserved. Capture a screenshot.

- [ ] **Step 5: Commit**

```bash
git add Packages/Feature-Library/Sources/FeatureLibrary
git commit -m "feat(app): tap a library poster → placeholder media detail (F3.1)"
```

---

## Self-Review

**Spec coverage:**
- Movies/Series sub-tabs over an adaptive grid → Task 4 (`LibraryView` segmented `Picker` + `PosterGrid`). ✓
- Tap → push media detail → Task 5 (`NavigationLink` + `MediaDetailStubView`). ✓
- Persisted selected tab → Task 2 (`UserDefaultsLibraryTabStore`) + Task 3 (`selectedTab` didSet). ✓
- Shared poster-size preference → Task 4 (`PosterSizeSlider` via `@Environment(PosterSizePreference.self)`). ✓
- Loading / empty / error states → Task 4 (`PosterGridSkeleton` / `EmptyStateView` / `ErrorStateView`). ✓
- Refresh: on-appear / foreground / re-select / pull; no poll → Task 3 (`loadIfNeeded`/`refresh`) + Task 4 (`.task(id:)`/`.onChange(scenePhase)`/`.refreshable`). ✓
- Endpoints + full payload (no pagination) → Task 1 (`MediaAPI`). ✓
- Sort = server order → no client sort applied (arrays rendered as returned). ✓
- No availability UI → `MediaCard` shows only poster/title/year; availability decoded but unrendered. ✓
- 401 routing → Task 4 Step 7 (`makeMediaAPI` uses the shared `onUnauthorized` hook). ✓

**Placeholder scan:** No TBD/TODO; every code step is complete. The "Full details coming soon" label is intentional product copy marking the F3.3 swap point, not a plan placeholder. ✓

**Type consistency:** `MediaAPI.libraryMovies/librarySeries(token:)` consistent across Tasks 1/3/4. `LibraryStore.LoadState` cases (`idle/loading/loaded/failed`) consistent across store + view. `state(for:)`, `loadIfNeeded(_:)`, `refresh(_:)`, `selectedTab` names match between Task 3 (definition) and Task 4 (consumption). `MediaDetailStub(movie:)`/`(series:)` match between Task 5 definition and `loadedContent` call sites. `grid(...)` signature in Task 4 (no `stub:`) is deliberately superseded by Task 5's signature (with `stub:`) — both call sites are updated in the same step. ✓
