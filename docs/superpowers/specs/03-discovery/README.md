# Epic 03 — Discovery: Library & Search

How a user finds media: browse what's already in the library, search the catalog by title, open a rich detail screen, and see — per card — whether a title is in the library, available, already requested, or requestable. This is the surface that feeds [Media Requests](../04-requests/README.md).

**Maps to:** `Feature-Library` + the discovery half of `Feature-Requests` · roadmap **Plans 2 & 3**.
**Source surface:** `web/src/routes/requests/{library,search}*.tsx`, `web/src/api/portal/{library,search}.ts`, `web/src/hooks/portal/use-portal-{library,search}.ts`, and the **shared media components** in `web/src/components/search/**` (modal, cards, seasons list, action buttons).

## Features

- [ ] [Library poster grid (Movies/Series tabs)](library-poster-grid.md) — browse in-library titles
- [ ] [Title search](title-search.md) — search movies & series; In-Library vs Request grouping
- [ ] [Rich media-detail screen](media-detail-screen.md) — extended metadata, cast, ratings, trailer *(second API base path)*
- [ ] [Per-card request state machine](request-state-card.md) — In Library / Available / Searching / Approved / Requested / View Request + inline progress
- [ ] [Series season & episode breakdown](season-episode-breakdown.md) — per-season badges, per-episode rows

## Notes

- **Two findings from the source review worth refiner attention:**
  1. The detail screen pulls **extended metadata from a second base path** (`/api/v1/metadata/*`, the admin `apiFetch` client, *not* `/api/v1/requests`). Whether a portal token authorizes it is an open question that gates the detail screen — see [media-detail-screen](media-detail-screen.md).
  2. The poster cards run a real **state machine** (own-vs-other request, searching shimmer, inline download bar) that's easy to under-build — captured separately as [request-state-card](request-state-card.md).
- The library and search surfaces **share** the same media components (`components/search/*`), so the detail screen, cards, and seasons list are built once and reused in both.
