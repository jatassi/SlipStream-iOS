---
epic: 06-notifications
status: unrefined
type: feature
v1: false
plan: "— (cut from v1 — revisit with push)"
---

# Inbox list & read-state

**Intent:** Let the user read their recent request notifications (approved / denied / available) and keep read-state effortless and consistent across devices.

> ✂️ **Cut from v1** (with [the bell](inbox-bell-badge.md)). Revisit alongside [push notifications](../08-deferred/push-notifications.md); until then the [request list](../04-requests/request-list.md) carries status.

## Summary
A compact list (popover or screen) of recent notifications with type, title, message, and relative timestamp, typed icons, an unread highlight, and empty/loading states. Opening it auto-marks-all-read; tapping an unread item marks just that one read — both mirrored to the server. A notification carries a `requestId`, so it can deep-link to the related request.

## In scope
- Notification list (`GET /api/v1/requests/inbox?limit=50&offset=0`).
- Typed icons + unread-row highlight; "Loading…" and "No notifications yet" states.
- Auto mark-all-read on open (`POST /inbox/read`) + per-item read on click (`POST /inbox/{id}/read`).
- Optional deep-link from a notification to its request detail (via `requestId`).

## Source of truth (web portal)
- `web/src/components/portal/notification-bell-list.tsx`, `use-notification-bell.ts`; `web/src/api/portal/inbox.ts`.
- Endpoints: `GET /inbox`, `GET /inbox/count`, `POST /inbox/read`, `POST /inbox/{id}/read` (mark-read endpoints return 204).

## iOS notes
- Decide auto-mark-all-on-open (web behavior) vs a more typical mobile mark-on-view.
- Deep-link tap → request detail (the `requestId` exists specifically for this; web doesn't currently navigate).

## Open questions
- [ ] Use the list response's `unreadCount`, or keep the separate `/inbox/count` call (as web does)?
- [ ] Notification types beyond the three (the icon switch has a fallback branch)?
- [ ] Server retention/limit — is `limit=50` effectively "all"?
- [ ] Tap → deep-link to the request?

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [request detail](../04-requests/request-detail.md), [app shell](../01-foundations/app-shell-navigation.md).
