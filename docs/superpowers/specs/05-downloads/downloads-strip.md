---
epic: 05-downloads
status: unrefined
type: feature
v1: true
plan: "own plan"
---

# Global active-downloads strip

**Intent:** Give the user an at-a-glance, app-wide view of every download currently in flight for their requests, without opening individual requests.

## Summary
A strip listing the user's active downloads (downloading / queued / paused), fed by the user-scoped `GET /api/v1/requests/downloads`. The fetch + poll are gated on whether any request is active, so an idle user generates no traffic.

## In scope
- App-wide strip of active downloads with title, progress, speed/ETA.
- Gate fetch + poll on active-request existence.
- Placement decision: a persistent header strip (as on web) vs a dedicated Activity/Downloads tab.

## Source of truth (web portal)
- `web/src/components/portal/portal-downloads.tsx`; App-shell "Live Download Progress Strip".
- `GET /api/v1/requests/downloads` → `PortalDownload[]`; `GET /api/v1/requests` (gates the fetch).

## iOS notes
- `PortalDownload.id` is a string but identity uses `clientId + id` — use a composite `Identifiable` key.
- `warning` status is excluded from the active strip on web — decide iOS treatment.

## Open questions
- [ ] Persistent header strip, or a dedicated Activity/Downloads tab on iOS?
- [ ] Identity uniqueness across multiple download clients (for SwiftUI `Identifiable`).
- [ ] What to show for a `warning`/`failed` download.

## Dependencies
- [Request ↔ download matching](download-request-matching.md), [polling engine](../01-foundations/polling-engine.md), [request list](../04-requests/request-list.md).
