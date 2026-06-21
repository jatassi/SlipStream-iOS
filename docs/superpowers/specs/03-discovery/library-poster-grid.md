---
epic: 03-discovery
status: refined
type: feature
v1: true
plan: "own plan"
---

# Library poster grid (Movies / Series tabs)

**Intent:** Let the user see at a glance everything already in the library, split by media type, so they know what they can watch.

## Summary
A two-sub-tab (Movies / Series) adaptive poster grid showing titles that exist in the server's library with files. Tapping a poster pushes a media-detail screen. F3.1 delivers the browse surface only — pure poster grid (poster + title + year), with all per-card availability/state rendering and any request-launch interaction deferred to F3.4 (per-card state machine) and F4.1 (create request).

## In scope
- Movies / Series sub-tabs (segmented control) over an adaptive poster grid.
- Tap a poster → push a media-detail screen.
- Persisted selected tab + shared poster-size preference.
- Per-tab loading (skeleton), empty, and error (retry) states.
- On-appear / foreground / pull-to-refresh data freshness (no aggressive poll).

## Out of scope (deferred to dependent features)
- **Availability badges / per-card state** (In Library / partial / requested / progress) → **F3.4**. Availability is decoded into the models but deliberately **not rendered** in F3.1.
- **Partial-series request launch** (season picker, monitor-future) → **F3.4 + F4.1**.
- **Rich media detail** (extended metadata, cast, ratings, trailer via the `/metadata` base) → **F3.3**. F3.1 ships a lightweight placeholder detail rendered from data already in the library payload; F3.3 replaces its body.

## Source of truth (web portal)
- `web/src/routes/requests/library.tsx`, `library-movie-card.tsx`, `library-series-card.tsx`, `use-portal-library.ts`, `api/portal/library.ts`.
- `GET /api/v1/requests/library/movies` → `PortalMovieSearchResult[]`.
- `GET /api/v1/requests/library/series` → `PortalSeriesSearchResult[]`.

## Resolved decisions (from refinement)
1. **Pagination** — none. Both endpoints return the **full library in one payload**; render in a single adaptive `LazyVGrid` (Nuke handles off-screen image cost; no virtualization needed for v1 library sizes).
2. **Persist selected tab** — **yes**. Backed by a `LibraryTabStore` UserDefaults seam (mirrors `ServerConfigStore` / `LastUsernameStore`); defaults to `.movies`.
3. **Sort order** — **trust server order** for v1 (matches web, which applies no client sort). Revisit with a client sort (title / `availability.addedAt`) only if server order proves unstable.
4. **Tap target** — push a **lightweight placeholder detail** rendered from the library payload (poster, title, year, overview). Makes navigation/selection real and testable now; F3.3 swaps the detail body.
5. **Availability UI** — **none** in F3.1 (pure poster grid). Partial series look identical to complete ones until F3.4.
6. **Refresh** — fetch on first appear; refresh the current tab on app-foreground and on sub-tab re-selection; `.refreshable` pull-to-refresh. **No `PollStream`** — the library is a heavy payload that changes slowly (web uses a 5-min staleness, not the 3s requests/downloads poll).

## Architecture

New **`Feature-Library`** SwiftPM package (deps: `SlipStreamKit` + `DesignSystem`). Kit-side logic lives in `SlipStreamKit` (headless-testable); only views live in `Feature-Library`. Composed into the shell by swapping `LibraryPlaceholderView()` for `LibraryView()` in `AppShellView.tab(.library)`.

### Components

**`MediaAPI` (SlipStreamKit/Networking)** — protocol + `PortalAPIClient` extension, mirroring `AuthAPI` / `SystemAPI`:
```swift
func libraryMovies(token: String) async throws -> [PortalMovieSearchResult]   // GET library/movies
func librarySeries(token: String) async throws -> [PortalSeriesSearchResult]  // GET library/series
```
Thin pass-throughs over `send(_:method:base:token:)` with `base: .portal` (→ `api/v1/requests/library/{movies,series}`).

**`LibraryTabStore` (SlipStreamKit)** — UserDefaults-backed protocol seam (real impl + fake), persists the selected sub-tab; defaults to `.movies`. `LibraryTab` is a `String`-raw `CaseIterable` enum (`movies`, `series`).

**`LibraryStore` (SlipStreamKit)** — `@MainActor @Observable`. Holds `movies` / `series` arrays plus an independent per-tab `LoadState` (`idle` / `loading` / `loaded` / `failed(String)`), mirroring the web's two independent queries. **Lazy**: a tab fetches on first appearance (open Movies, never open Series → series never fetched). `selectedTab` getter/setter is backed by `LibraryTabStore` (persisted on set). Injected with `makeMediaAPI: @Sendable (URL) -> MediaAPI`, a `ServerConfigStore` (for the base URL), and a `tokenProvider: @MainActor () -> String?` (reads `auth.currentToken`) — the same seam style as `AuthStore`. The client is built with the app's shared `onUnauthorized` hook, so a token-bearing library 401 funnels through `SessionExpiry` (F2.4) → logout. Signed-out / no-token / no-base-URL → fetches are a no-op.

**Views (`Feature-Library`):**
- `LibraryView` — segmented `Picker` (Movies / Series) bound to `store.selectedTab`; poster-size control in a toolbar `Menu` (saves vertical space vs. inline); `DesignSystem.PosterGrid` of cards; per-tab `PosterGridSkeleton` / `EmptyStateView` / `ErrorStateView`; `.refreshable`, `.task` (load current tab), `.onChange(selectedTab)` (lazy-load), `.onChange(scenePhase → .active)` (refresh current tab). Reads `@Environment(LibraryStore.self)` and `@Environment(PosterSizePreference.self)`.
- `MediaCard` — `PosterImage(url:module:)` + title + year. Nothing else.
- `MediaDetailStubView` — placeholder detail (poster + title / year / overview), clearly marked as the F3.3 swap point.

### Data flow & navigation
Tap → `NavigationLink(value: MediaDetailStub(...))` pushes onto the shell-provided `NavigationStack`; `.navigationDestination(for: MediaDetailStub.self)` renders `MediaDetailStubView`. `MediaDetailStub` is a small **`Hashable` presentation type local to `Feature-Library`** (built from either model at tap time) — keeps `SlipStreamKit` models as pure JSON mirrors and avoids a `Hashable`-conformance chain; F3.3 will define its own richer detail model.

### States (per tab)
loading → 12-cell `PosterGridSkeleton` · loaded(non-empty) → grid · loaded(empty) → `EmptyStateView` ("No movies available" / "No series available", "Movies/Series with files will appear here") · failed → `ErrorStateView(message:retry:)`.

## App composition
`SlipStreamApp` composes one `LibraryStore` (`makeMediaAPI` using the shared `onUnauthorized` hook, `serverConfig`, `tokenProvider: { auth.currentToken }`), injects it via `.environment(...)`, and `AppShellView` swaps the Library tab body to `LibraryView()`. F1.4/F1.5/F1.6/F1.7/F2.4 wiring on the signed-in path is preserved (anchored edits only — see the file-replace regression hazard).

## Testing (TDD, headless `swift test`, swift-testing)
- `LibraryTabStoreTests` — persist/restore, default `.movies` when unset.
- `LibraryStoreTests` (with `FakeMediaAPI`) — load success populates + `.loaded`; empty payload → `.loaded` empty (drives empty state); failure → `.failed(message)`; lazy (loading movies does not fetch series); refresh re-fetches the current tab; `selectedTab` setter persists through the tab store; signed-out / no-token → no-op (no API call).
- `MediaAPI` path/decoding — covered at store level via `FakeMediaAPI`; a client-level URLProtocol test only if existing precedent warrants it (mirrors F2.4 — kit unit tests are the gate; a live run verifies the on-device loop).

## Dependencies
- [Design system & image loading](../01-foundations/design-system-image-loading.md) (PosterGrid / PosterImage / PosterSizeSlider / skeleton / empty / error), [app shell & navigation](../01-foundations/app-shell-navigation.md) (Library tab slot + NavigationStack), [portal API client](../01-foundations/portal-api-client.md), [data contract](../01-foundations/data-contract-models.md) (search-result + availability models).
- **Feeds:** [media detail](media-detail-screen.md) (F3.3 replaces the stub), [per-card state](request-state-card.md) (F3.4 adds availability rendering), [season breakdown](season-episode-breakdown.md) (F3.5).
