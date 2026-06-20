# Epic 05 — Downloads & Progress

Read-only, live download progress for the user's own requests: an app-wide strip of everything in flight, a per-request progress card, and the matching logic that ties queue items back to requests. Updates come from polling the **user-scoped** downloads endpoint (the server filters to the caller's own requests).

**Maps to:** the live-progress slice of `Feature-Requests` + the **Plan 4** poller.
**Source surface:** `web/src/components/portal/portal-downloads.tsx`, `web/src/routes/requests/request-download-progress.tsx` + `request-download-utils.ts`, `web/src/api/portal/requests.ts` (`downloads`), plus the web's WebSocket queue path (`stores/portal-downloads.ts`, `stores/ws-message-handlers.ts`).

## Features

- [ ] [Global active-downloads strip](downloads-strip.md) — app-wide view of in-flight downloads
- [ ] [Per-request download progress](request-download-progress.md) — aggregated progress for one request
- [ ] [Request ↔ download matching](download-request-matching.md) — associate queue items to requests (mediaId → title)

## Notes

- `PortalDownload.status` includes `queued · downloading · paused · completed · failed · warning`; the web progress UI doesn't explicitly handle `warning`/`failed` everywhere — an iOS gap to design.
- **Contract subtlety:** on the web, the live queue strip is actually **WebSocket-fed** (`queue:state`) with client-side request-matching, and the REST `/downloads` poll is a parallel/fallback path. iOS will **poll** `/downloads` (no portal websocket exists), but it still needs the same [matching algorithm](download-request-matching.md).
