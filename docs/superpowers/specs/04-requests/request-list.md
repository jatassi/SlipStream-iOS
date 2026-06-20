---
epic: 04-requests
status: unrefined
type: feature
v1: true
plan: "Plan 3"
---

# Request list (Mine / All) with live status

**Intent:** Give the user a single scrollable history of media requests — their own by default, with the option to see the whole household's — so they can track what they've asked for and what's downloading.

## Summary
`GET /api/v1/requests` with `scope=mine|all`. Each row shows the request's 8-state status, refreshing while any request is active, with inline download progress for downloading rows. The client also supports status/mediaType/userId filters that the web UI doesn't surface.

## In scope
- List with a **Mine / All** scope toggle.
- 8-state status display per row.
- Inline [download progress](../05-downloads/request-download-progress.md) for downloading rows.
- Pull-to-refresh; [poll](../01-foundations/polling-engine.md) while active requests exist.

## Source of truth (web portal)
- `web/src/routes/requests/index.tsx`; `web/src/hooks/portal/use-requests.ts`; status display in `request-status-config.tsx`.
- `GET /api/v1/requests?scope=mine` / `?scope=all`; `RequestListFilters` also supports `status` / `mediaType` / `userId`.

## iOS notes
- Status config (8 states + colors/labels) mirrors `request-status-config.tsx`.
- Poll cadence per the [polling engine](../01-foundations/polling-engine.md).

## Open questions
- [ ] `all` scope exposes every household member's requests to a portal user — confirm that's intended for the trusted-family audience (and not admin-only).
- [ ] Add status/mediaType filtering, or match the web's scope-only UX?
- [ ] Pull-to-refresh expectation (unspecified on web).

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [polling engine](../01-foundations/polling-engine.md), [per-request download progress](../05-downloads/request-download-progress.md), [request detail](request-detail.md).
