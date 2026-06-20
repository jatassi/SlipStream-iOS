---
epic: 01-foundations
status: unrefined
type: feature
v1: true
plan: "own plan"
---

# Real-time polling engine

**Intent:** Keep request statuses, download progress, and inbox counts fresh without manual refresh — the portal's substitute for websockets.

## Summary
A shared `@Observable` poller in `SlipStreamKit` refetches the active views on a short interval while foregrounded and pauses in the background. Polling is gated on whether the user has active requests (so an idle user makes no traffic). The portal client has **no websocket** — the server `/ws` is admin-audience only.

## In scope
- One poller policy shared by all active screens (rather than each view inventing its own).
- Cadence: web uses ~5s for the request list, ~3s for downloads, ~30s for `/status`; project target is ~3s for the live views.
- Start/stop on `scenePhase` (pause in background); pause immediately on a `401`.
- Gate download polling on active-request existence.

## Source of truth (web portal)
- `web/src/hooks/portal/use-requests.ts` (React Query `refetchInterval`s), App-shell area "Real-time via Interval Polling".
- Web's live download strip is actually WebSocket-fed (`queue:state`) — that path is admin/infra and out of scope; see [Epic 05 · matching](../05-downloads/download-request-matching.md).

## iOS notes
- Single poller (its own plan); respect `scenePhase`; don't poll an idle app.
- Decide uniform 3s vs preserving the web's 5s-requests / 3s-downloads split.

## Open questions
- [ ] Uniform 3s (simpler) or match the web's 5s/3s split?
- [ ] Background behavior — hard-stop, or a slow heartbeat?

## Dependencies
- [Portal API client](portal-api-client.md); drives [request list](../04-requests/request-list.md), [downloads strip](../05-downloads/downloads-strip.md), [inbox bell](../06-notifications/inbox-bell-badge.md).
