---
epic: 03-discovery
status: unrefined
type: feature
v1: true
plan: "Plan 3"
---

# Title search (movies & series)

**Intent:** Give the user a single field to search the catalog by title and instantly see what's already available vs. what's new and requestable.

## Summary
A text query runs movie and series searches; results are grouped **In Library** vs **Request**, separately per media type, each item carrying its own availability. Movies can be requested in one tap from a result; series open the season-picker. Search is entered from the shell header and lands on a results screen.

## In scope
- Search input + submission; results screen seeded with the query.
- Movie + series results with In-Library / Requestable categorization.
- Per-item availability driving the [card state](request-state-card.md).

## Source of truth (web portal)
- `web/src/routes/requests/search.tsx`, `search-media-grids.tsx`, `search-results-content.tsx`, `request-list-search.tsx`, `use-request-search.ts`, `use-portal-search.ts`.
- `GET /api/v1/requests/search/movie?query=<q>` → `PortalMovieSearchResult[]` (with `availability`).
- `GET /api/v1/requests/search/series?query=<q>` → `PortalSeriesSearchResult[]` (with `availability`, network/logo).

## iOS notes
- Debounce input; availability is computed per authenticated user's server (confirm).
- Results grids have a show-more/less ("collapsible") affordance on web — decide the iOS equivalent.

## Open questions
- [ ] Server-side debounce / rate limit on `/search/*` the client must respect?
- [ ] Confirm availability ("In Library") is computed for the authenticated portal user's scope.

## Dependencies
- [Per-card state](request-state-card.md), [create request](../04-requests/create-request.md), [media detail](media-detail-screen.md), [app shell](../01-foundations/app-shell-navigation.md).
