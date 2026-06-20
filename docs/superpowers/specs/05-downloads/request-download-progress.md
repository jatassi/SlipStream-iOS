---
epic: 05-downloads
status: unrefined
type: feature
v1: true
plan: "own plan"
---

# Per-request download progress

**Intent:** On a single request's row/detail, show the aggregated download progress for just that request, so the user knows how close their movie/season is to ready.

## Summary
Filters the shared `/downloads` feed to the request's `mediaId` and aggregates progress (percent, speed, ETA, size). At ≥100% it shows an "Importing" transition; failed/warning states and mixed paused/downloading need defined precedence. Used inline in the request list and on the request detail, and reused for the [per-card inline bar](../03-discovery/request-state-card.md).

## In scope
- Per-request inline progress card aggregating matching downloads.
- Percent / speed / ETA / size; "Importing" at ≥100%.
- Failed / warning handling; mixed paused/downloading precedence.

## Source of truth (web portal)
- `web/src/routes/requests/request-download-progress.tsx`, `request-download-utils.ts`.
- `GET /api/v1/requests/downloads` (filtered client-side by `mediaId`); `GET /api/v1/requests`.

## iOS notes
- Reuse the shared downloads data + the [matching](download-request-matching.md) logic.
- Season/episode-level requests (`mediaType` `season`/`episode`) aren't matched on web — decide if iOS needs finer-grained matching.

## Open questions
- [ ] Match season/episode-level requests, or only movie/series `mediaId`?
- [ ] Precedence for mixed paused/downloading items.
- [ ] Does the card vanish at `available`, or transition through "Importing"?

## Dependencies
- [Request ↔ download matching](download-request-matching.md), [Codable data contract](../01-foundations/data-contract-models.md).
