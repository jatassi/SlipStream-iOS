---
epic: 04-requests
status: unrefined
type: feature
v1: true
plan: "Plan 3"
---

# Request detail

**Intent:** Show everything about one request on its own screen: media identity, who requested it and when, current status, approval/denial details, and live download progress.

## Summary
`GET /api/v1/requests/{id}` backs a detail screen showing the request's media, requester + timestamp, current status, denial reason / approval info, and — while downloading — the [per-request download progress](../05-downloads/request-download-progress.md). It's also the entry point for [cancel](cancel-request.md) and [watch](watch-request.md).

## In scope
- Single-request detail view; status + denial reason / approval info.
- Embedded per-request download progress.
- Cancel / watch entry points.
- Keep the open detail live (polling decision below).

## Source of truth (web portal)
- `web/src/routes/requests/$id.tsx`, `request-detail-card.tsx`, `request-detail-header.tsx`, `use-request-detail.ts`.
- `GET /api/v1/requests/{id}` → `Request`.

## iOS notes
- On web the detail query has **no polling of its own** (it refreshes via invalidations from watch/cancel and the list-driven downloads poll) — decide whether iOS polls `GET /{id}` on a ~3s timer while the screen is open.
- `approvedBy` is a bare user id with no name resolution (web omits it).

## Open questions
- [ ] Poll the open detail on a timer, or rely on invalidations like the web?
- [ ] Resolve `approvedBy` to a username, or omit it as the web does?

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [per-request download progress](../05-downloads/request-download-progress.md), [cancel](cancel-request.md), [watch](watch-request.md), [polling engine](../01-foundations/polling-engine.md).
