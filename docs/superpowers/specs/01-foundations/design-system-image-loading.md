---
epic: 01-foundations
status: refined
type: feature
v1: true
plan: "own plan"
---

# Design system & visual identity

**Intent:** Establish the iOS app's visual identity and the shared SwiftUI building
blocks that every media-heavy screen (Discovery, Requests, Detail, Downloads)
reuses. F1.7 mirrors the SlipStream web portal's look — a **dark-first, "neon
noir" media dashboard** with movie-orange / tv-blue brand accents — and ships the
high-throughput poster/artwork image loading those screens depend on.

> **Refined 2026-06-20** from "Design system & image loading". Scope was widened
> from a poster-component kit to the **full visual identity** (theme tokens,
> typography, brand, status palette) after surveying the web design system
> (`~/Git/SlipStream/web/src`). See *Resolved decisions* below.

## Resolved decisions

- **Scope = full identity.** Beyond the poster components, F1.7 establishes the
  theme token layer, Inter typography, brand pieces (gradient logo + glow), and
  the request-status color palette. (Earlier "components only" and "theme +
  components" options were rejected in favour of the full identity.)
- **Appearance = force dark only.** The app locks to dark mode
  (`.preferredColorScheme(.dark)`); a single dark token set, mirroring the web's
  dark-first identity (its brand palettes are defined for dark only). No light
  theme in v1.
- **Poster-size control ships on phone too**, with a mobile-aware step (25 on
  compact width, 10 on regular) — mirrors the web's `isMobile ? 25 : 10`.
- **Poster-size preference is shared/global**, not per-screen — one persisted,
  observable `PosterSizePreference` injected via the SwiftUI environment, mirroring
  the web's single shared UI store.
- **Reuse existing contract enums.** The accent driver is the existing
  `ModuleType { movie, tv }`; the status palette maps the existing
  `RequestStatus` (8 cases). No new `PosterKind` enum.

## Architecture

Two homes, mirroring the existing package split:

- **`SlipStreamKit`** (pure, no SwiftUI; tested headlessly via `swift test` on the
  macOS host): the testable values & logic —
  - `PosterGridMetrics` — sizing range/default/step + `clamp`/`step` helpers.
  - `PosterSizePreference` (+ `PosterSizeStoring` / `UserDefaultsPosterSizeStore`)
    — persisted, `@Observable` poster-size preference.
  - Pure design constants — `RadiusScale` and the type-ramp point sizes.

- **`DesignSystem`** (new, iOS-only package like `Feature-Auth`; depends on
  `SlipStreamKit` + Nuke): everything SwiftUI —
  - the force-dark **token palette** (`DesignTheme` colours),
  - **typography** (bundled Inter Variable + a `Font` ramp),
  - **components** (`PosterImage`, `PosterGrid`, `PosterSizeSlider`, skeletons,
    empty/error states),
  - **brand** (`SlipStreamLogoMark` / wordmark, `.glow(_:)` modifier, media
    gradient),
  - the **status palette** (`RequestStatus → colour + icon`, `StatusBadge`),
  - `DesignTheme.bootstrap()` (Nuke pipeline + font registration) and
    `PosterImagePipeline.clearImageCache()` (sign-out),
  - a **DEBUG-only `DesignSystemGalleryView`** living catalog.

## Token layer (force-dark, single set)

Values are converted from the web's OKLCH tokens (`web/src/index.css`) to
sRGB/Display-P3 and documented at their definition site (the OKLCH source is the
authority; SwiftUI has no OKLCH initializer).

- **Semantic:** `background oklch(0.145 0 0)`, `surface`/`card oklch(0.205 0 0)`,
  `foreground oklch(0.985 0 0)`, `secondary`/`muted oklch(0.269 0 0)`,
  `mutedForeground oklch(0.708 0 0)`, `accent oklch(0.371 0 0)`,
  `border white @ 10%`, `destructive oklch(0.704 0.191 22.216)`.
- **Brand:** `movie` orange `oklch(0.72 0.16 55)`, `tv` blue
  `oklch(0.675 0.17 243)`, plus muted (`-700`) and vibrant (`-400`) steps; the
  orange→blue **media gradient** (`movie-500 → tv-500`). `ModuleType` selects the
  accent.
- **Radius:** base `0.45rem ≈ 7pt` (`rounded-lg`); pill radius for badges
  (`rounded-4xl`).

## Typography

Bundle **Inter Variable** (OFL) as a `DesignSystem` resource, register it at
launch in `DesignTheme.bootstrap()`, and expose a `Font` ramp mirroring the web's
sizes: 24 (page title) / 20 (section) / 16 (card title) / 14 (body) / 12
(metadata) / 10 (badge), with medium/semibold weights where the web uses them.

## Components

- **`PosterImage`** — Nuke-backed (`NukeUI.LazyImage`), 2:3 portrait, `rounded-lg`
  corner, muted-fill **pulse** while loading, image scaled-to-fill on success, and
  a `ModuleType`-tinted film/tv SF-Symbol fallback on failure (web `FallbackIcon`).
  Consumes a server-resolved `URL?`; **artwork-URL construction is Epic 03's job**,
  out of scope here.
- **`.glow(_ accent:)`** — the movie/tv neon shadow the web applies on hover
  (`box-shadow: 0 0 15px var(--movie-500)`), available to callers (selection/press).
- **`PosterGrid`** — adaptive `LazyVGrid` with `GridItem(.adaptive(minimum:))`, the
  SwiftUI equivalent of `repeat(auto-fill, minmax(posterSize, 1fr))`. Bare grid;
  caller supplies the `ScrollView`.
- **`PosterSizeSlider`** — bound to the shared `PosterSizePreference`, range
  100–250, mobile-aware step.
- **Skeletons** — `PosterCellSkeleton` / `PosterGridSkeleton` / `SearchLoadingSkeleton`,
  using the pulse **and** the web's shimmer-sweep (`animate-skeleton-shimmer`).
- **State views** — `EmptyStateView` + `ErrorStateView` over `ContentUnavailableView`,
  themed (destructive colour for the error glyph; Retry action).

## Brand

- **`SlipStreamLogoMark`** — rounded square filled with the media gradient + "SS"
  wordmark, optional glow; **gradient wordmark** ("SlipStream" with the media
  gradient as `foregroundStyle`).

## Status palette

A pure `RequestStatus → (colour, SF-Symbol)` mapping plus a pill **`StatusBadge`**
view, mirroring `web/src/lib/request-status-config.tsx`: pending=yellow/Clock,
approved=blue/check, searching=blue/spinner, downloading=purple/Download,
available=green/check, denied=red/x, failed=dark-red/x, cancelled=gray/x. Defined
here (its natural home); consumed by Epics 03–04.

## Integration (and the staleness fixes)

The pre-refinement plan's verbatim file-replaces would have regressed
F1.4/F1.5/F1.6 wiring and referenced the deleted `SignedInPlaceholderView`. The
refined integration is **surgical**:

- `App/SlipStreamApp.swift` — keep the existing `auth` / `system` / `poller` /
  `navigation` environment injection and `onUnauthorized` wiring; **add**
  `DesignTheme.bootstrap()`, inject a shared app-level `PosterSizePreference`, and
  apply `.preferredColorScheme(.dark)`.
- `App/RootView.swift` — keep `AppShellView()` and the polling/system/scenePhase
  wiring; surface the DEBUG gallery via a floating button → `.sheet`
  (**no nested `TabView`**; reachable pre-auth).
- Poster cache clear — reactive `.onChange(of: auth.state)` at the app layer
  (covers manual sign-out **and** F2.4's future auto-logout); no edit to the
  Settings sign-out button.

## Source of truth (web portal)

`web/src/index.css` (tokens), `web/src/lib/request-status-config.tsx` (status
colours), `web/src/components/media/poster-image.tsx` + `components/search/*-card.tsx`
(poster styling), `routes/requests/library.tsx` (`PosterSizeSlider`, `GridSkeleton`),
`stores/ui.ts` (`posterSize`), `routes/requests/search-loading-skeleton.tsx`,
`components/data/empty-state.tsx` + `error-state.tsx`. **Re-pin all numeric values
against current source** in the plan's first task (the survey already found one
drift: media grids now use `gap-3`/12pt, not 16pt).

## Testing

- **Headless** (`cd Packages/SlipStreamKit && swift test`): `PosterGridMetrics`,
  `PosterSizePreference`, design constants.
- **On-device:** `DesignSystem` is SwiftUI/iOS-only — verified by building and
  screenshotting the DEBUG gallery on **iPhone 17** and **iPad Pro 13" (M4)**.

## Dependencies

- **New external dependency:** Nuke (`NukeUI` + `Nuke`) — the project's first and
  only third-party package, declared by `DesignSystem`.
- Consumed by Epic 03 (Discovery) onward. No networking/contract work here.
