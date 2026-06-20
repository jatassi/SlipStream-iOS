---
epic: 06-notifications
status: unrefined
type: feature
v1: false
plan: "— (cut from v1 — revisit with push)"
---

# Inbox bell & unread indicator

**Intent:** Give the user an always-visible header affordance that tells them at a glance whether they have unread notifications.

## Summary
A bell in the shell header with an unread red-dot fed by `GET /api/v1/requests/inbox/count`. The web shows a binary dot (not a number) and updates it on focus/refetch; iOS would refresh it via the polling engine and could optionally show the numeric count.

> ✂️ **Cut from v1.** Status is conveyed by the [request list](../04-requests/request-list.md)'s live 8-state status + external [delivery channels](delivery-channels-manage.md). Revisit the in-app inbox alongside [push notifications](../08-deferred/push-notifications.md).

## In scope
- Header bell with an unread indicator from `/inbox/count`.
- Refresh cadence (web doesn't poll it; iOS via the [polling engine](../01-foundations/polling-engine.md)).
- Opens the [inbox list](inbox-list-read-state.md).

## Source of truth (web portal)
- `web/src/components/portal/notification-bell.tsx`, `use-notification-bell.ts`.
- `GET /api/v1/requests/inbox/count` → `{ count: number }`.

## iOS notes
- Decide numeric badge vs binary dot; choose a poll cadence (web doesn't poll the count at all).

## Open questions
- [ ] Surface the numeric unread count, or replicate the web's binary dot?
- [ ] Poll cadence for the count on iOS.

## Dependencies
- [Inbox list & read-state](inbox-list-read-state.md), [polling engine](../01-foundations/polling-engine.md), [app shell](../01-foundations/app-shell-navigation.md).
