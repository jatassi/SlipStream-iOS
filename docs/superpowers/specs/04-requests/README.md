# Epic 04 — Media Requests

The core portal action: submit a request, track your own (and optionally the household's) requests with live status, drill into one, cancel it before approval, and follow requests you didn't create. This is the heart of the portal experience after discovery.

**Maps to:** `Feature-Requests`; each feature is its own plan (live status via the [polling engine](../01-foundations/polling-engine.md), F1.5).
**Source surface:** `web/src/api/portal/requests.ts`, `web/src/hooks/portal/use-requests.ts`, `web/src/routes/requests/{index,$id,request-detail-*,request-status-config,series-request-dialog}.tsx`.

## Features

- [ ] [Create request (movie + season picker)](create-request.md) — one-tap movies; series season/monitor-future dialog
- [ ] [Request list (Mine / All) with live status](request-list.md) — scrollable history, 8-state status
- [ ] [Request detail](request-detail.md) — status, metadata, approval/denial, live progress
- [ ] [Cancel a pending request](cancel-request.md) — owner-only, with confirmation
- [ ] [Watch / unwatch another user's request](watch-request.md) — follow the household's requests

## Notes

- `RequestStatus` is an **8-state enum**: `pending · approved · denied · searching · downloading · failed · available · cancelled` — see `web/src/routes/requests/request-status-config.tsx` for display mapping.
- **Payload subtlety** (load-bearing for the create contract): a *single-season* selection is sent as `mediaType: 'season'` with a `seasonNumber`; *zero seasons + monitor-future* submits a future-only `series` request with no `requestedSeasons`. Captured in [create-request](create-request.md).
- Download progress shown inline in the list and on detail comes from [Epic 05](../05-downloads/README.md).
- **Out of scope:** approve/deny, batch actions, and the admin request queue (admin surface; a portal token can't call them).
