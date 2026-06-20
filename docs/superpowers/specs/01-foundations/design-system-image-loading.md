---
epic: 01-foundations
status: unrefined
type: feature
v1: true
plan: "Plan 2"
---

# Design system & image loading

**Intent:** Provide the shared SwiftUI components, theming, and high-throughput poster/artwork image loading that the discovery, request, and detail screens all reuse.

## Summary
A `DesignSystem` package with Nuke-backed cached image loading, an adaptive poster grid, loading skeletons, and standard empty/error states. Centralizing these keeps the media-heavy screens fast and consistent.

## In scope
- Nuke image cache + a poster image view (high poster throughput).
- Adaptive `LazyVGrid` poster grid with a sensible minimum item width.
- A **persisted** poster-size preference (the web keeps this in a shared, persisted UI store with a mobile-aware step), not a throwaway local toggle.
- Reusable loading skeletons and empty/error components.

## Source of truth (web portal)
- `web/src/routes/requests/library.tsx` (`PosterSizeSlider`, `GridSkeleton`), `web/src/stores/ui.ts` (`posterSize`, `setPosterSize`), `web/src/routes/requests/search-loading-skeleton.tsx`.
- Setup doc §1 names **Nuke** as the image stack.

## iOS notes
- `DesignSystem` package (Plan 2); persist poster size in a preference store shared across media surfaces.
- Consider clearing the Nuke cache on sign-out (shared family device) — see [sign-out](../02-authentication/sign-out.md).

## Open questions
- [ ] Port the poster-size control to phone, or just rely on an adaptive grid with a fixed minimum width there?
- [ ] Share the poster-size preference across all media surfaces (as web does) or scope per screen?

## Dependencies
- None (consumed by Epic 03 Discovery).
