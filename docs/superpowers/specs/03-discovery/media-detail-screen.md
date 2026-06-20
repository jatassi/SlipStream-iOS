---
epic: 03-discovery
status: unrefined
type: feature
v1: true
plan: "own plan"
---

# Rich media-detail screen (extended metadata)

**Intent:** Let the user open a title to see full details — cast, ratings, genres, runtime, content rating, director/creators/studio, and a trailer — plus its current availability/request status.

> ✅ **Resolved — portal token works.** The extended metadata comes from a **second base path** — `/api/v1/metadata/movie|series/{tmdbId}/extended` (base `/api/v1`, the non-portal client, **not** `/api/v1/requests`). A **portal Bearer token is authorized** there: the server mounts the `/metadata` group under `AnyAuth()`, which accepts either audience (`internal/api/routes.go:223-225`). The only non-auth caveat is that a TMDB metadata provider must be configured server-side (else `503`, not `401`).

## Summary
A rich detail screen (a modal on web) that lazily fetches an extended-metadata payload and renders multi-source ratings (IMDb/TMDB/RT), a horizontally-scrolling cast list with photos and roles, genres, runtime, content rating, and director (movies) / creators + studio (series), each with its own loading skeleton. It also computes request/download status from the user's requests + downloads, exposes a **Play Trailer** action, and — for series — hosts the [season & episode breakdown](season-episode-breakdown.md).

## In scope
- Fetch + render extended metadata (ratings, cast, genres, runtime, content rating, director/creators/studio) with per-block skeletons.
- **Play Trailer** — open `trailerUrl`.
- Status chips (in-library / downloading / available) derived from the user's requests + downloads.
- For series: embed the season/episode breakdown and the request flow.

## Source of truth (web portal)
- `web/src/components/search/media-info-modal.tsx`, `media-info-header.tsx`, `cast-list`, `ratings-display`, `media-action-button.tsx` (`TrailerButton`).
- `web/src/hooks/use-metadata.ts` → `web/src/api/metadata.ts` `getExtendedMovie/getExtendedSeries`.
- `GET /api/v1/metadata/movie/{tmdbId}/extended` → `ExtendedMovieResult`; `GET /api/v1/metadata/series/{tmdbId}/extended` → `ExtendedSeriesResult`.
- Status: `GET /api/v1/requests/downloads` + `GET /api/v1/requests`. Used by `library-movie-card.tsx`, `library-series-card.tsx`, and `external-media-card.tsx` (search).

## iOS notes
- This is effectively a **whole screen + a second data contract** — model `ExtendedMovieResult/ExtendedSeriesResult` and a `/api/v1/metadata/*` client (base `/api/v1`) separately from the portal client, but reuse the **same stored portal JWT** as its Bearer token (the `/metadata` group accepts it).
- Trailer → open YouTube/Safari, or in-app `AVPlayer`.

## Open questions
- [x] ~~Does a portal JWT authorize `/api/v1/metadata/*`?~~ **Resolved: yes** — the `/metadata` group is under `AnyAuth()`, which accepts the portal audience.
- [ ] Trailer playback: external link vs in-app player?
- [ ] Show the same status chips the web computes, given iOS's polling model?
- [ ] Degrade gracefully on `503 no metadata providers configured` (show the basic poster/title without extended metadata).

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [per-card state](request-state-card.md), [season breakdown](season-episode-breakdown.md), [design system](../01-foundations/design-system-image-loading.md), [per-request download progress](../05-downloads/request-download-progress.md).
