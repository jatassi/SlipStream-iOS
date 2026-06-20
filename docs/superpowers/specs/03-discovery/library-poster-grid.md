---
epic: 03-discovery
status: unrefined
type: feature
v1: true
plan: "Plan 2"
---

# Library poster grid (Movies / Series tabs)

**Intent:** Let the user see at a glance everything already in the library, split by media type, so they know what they can watch and what's still missing.

## Summary
A two-tab (Movies / Series) poster grid showing titles that exist in the server's library with files. Tapping a poster opens the [detail screen](media-detail-screen.md); for partially-available series, the user can launch a request for the missing seasons from here.

## In scope
- Movies / Series tabs over an adaptive poster grid.
- Tap a poster → media detail.
- Persisted selected tab + poster-size preference; loading and empty states.

## Source of truth (web portal)
- `web/src/routes/requests/library.tsx`, `library-movie-card.tsx`, `library-series-card.tsx`, `use-portal-library.ts`.
- `GET /api/v1/requests/library/movies` → `PortalMovieSearchResult[]`.
- `GET /api/v1/requests/library/series` → `PortalSeriesSearchResult[]`.

## iOS notes
- Adaptive `LazyVGrid` from the [design system](../01-foundations/design-system-image-loading.md); poster size from the shared preference.
- Cards carry availability, so they drive the [per-card state machine](request-state-card.md) for partial series.

## Open questions
- [ ] Is there server-side pagination/limit on `/library/*`, or always the full library in one payload? (Affects list virtualization/memory.)
- [ ] Persist the last-selected tab across launches, or always default to Movies?
- [ ] Guaranteed server sort order, or should iOS sort (e.g. by title or `availability.addedAt`)?

## Dependencies
- [Design system & image loading](../01-foundations/design-system-image-loading.md), [media detail](media-detail-screen.md), [per-card state](request-state-card.md), [season breakdown](season-episode-breakdown.md).
