---
epic: 04-requests
status: unrefined
type: feature
v1: true
plan: "own plan"
---

# Create request (movie + series season picker)

**Intent:** Let the user actually request content found via discovery — a one-tap add for movies, and a richer dialog for series to choose seasons and whether to monitor future episodes.

## Summary
`POST /api/v1/requests` with a `CreateRequestInput`. Movies are one tap. Series open a season-picker dialog (which seasons, plus a monitor-future toggle). The payload has **branches that matter**: a single-season selection is sent as `mediaType: 'season'` + `seasonNumber`; selecting zero seasons with monitor-future submits a future-only `series` request (no `requestedSeasons`); multiple seasons go as a `series` request with `requestedSeasons`.

## In scope
- Movie one-tap create.
- Series season-picker (choose seasons, monitor-future toggle; reuse the [season breakdown](../03-discovery/season-episode-breakdown.md)).
- The `mediaType` payload branches (season / series / future-only).
- Optionally auto-[watch](watch-request.md) the new request; surface duplicate / quota errors.

## Source of truth (web portal)
- `web/src/api/portal/requests.ts` `create`; `web/src/routes/requests/series-request-dialog.tsx`; `use-request-search.ts` / `use-portal-library.ts` `buildSeriesRequestPayload`.
- `POST /api/v1/requests` — body `CreateRequestInput { mediaType, tmdbId?, tvdbId?, title, year?, seasonNumber?, monitorFuture?, posterUrl?, requestedSeasons? }` → `Request`.

## iOS notes
- Season picker as a sheet; replicate the `mediaType` branch logic exactly (it's part of the wire contract).

## Open questions
- [ ] What does the server do when `requestedSeasons` is omitted on a `series` request — all missing seasons, monitored only, or future-only?
- [ ] Does `POST /requests` return a 4xx on quota exceeded, and what's the error shape (for a meaningful iOS message)?
- [ ] Are movies ever re-requested from the library (web has a handler but it appears unused there)?

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [season breakdown](../03-discovery/season-episode-breakdown.md), [per-card state](../03-discovery/request-state-card.md), [watch request](watch-request.md).
