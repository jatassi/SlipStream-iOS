---
epic: 05-downloads
status: unrefined
type: feature
v1: true
plan: "own plan"
---

# Request ↔ download matching

**Intent:** Reliably associate live download-queue items with the user's requests so both the global strip and the per-request card show the right progress against the right title.

## Summary
The web associates queue items to requests by `mediaId`, falling back to normalized-title matching. On the web this runs over a **WebSocket** `queue:state` stream (with the REST `/downloads` poll as a parallel/fallback). iOS will **poll** `/downloads` and needs the same matching algorithm — this is non-trivial shared infrastructure, not a screen.

## In scope
- Match downloads to requests by `mediaId`, falling back to normalized title.
- Reconcile the `/downloads` list into the global strip + per-request views.
- iOS uses polling (no portal websocket); document the matching as a reusable utility.

## Source of truth (web portal)
- `web/src/stores/ws-message-handlers.ts` (`handleQueueEvent`: `queue:state` → `setQueue`), `web/src/stores/portal-downloads.ts` (`normalizeTitle`, `matchByMediaId`), `web/src/hooks/use-queue.ts`.
- REST path: `web/src/hooks/portal/use-requests.ts` `usePortalDownloads` (`/downloads`, ~3s poll).

## iOS notes
- Port the matching algorithm into a tested `SlipStreamKit` utility; it's used by the strip, the per-request card, and the discovery cards' inline bars.

## Open questions
- [ ] Exact `normalizeTitle` rules and the `mediaId`-vs-title precedence.
- [ ] Confirm `/downloads` returns **only the caller's** items (request-scoped), not the whole household queue.

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [polling engine](../01-foundations/polling-engine.md).
