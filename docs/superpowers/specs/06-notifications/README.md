# Epic 06 — Notifications

Two halves of "keeping the user informed about their requests":

1. **In-app inbox** — a header bell with an unread indicator and a list of recent request-lifecycle notifications (approved / denied / available), with read-state mirrored to the server.
2. **Delivery channels** — the user's own external notification channels (Discord, Telegram, ntfy, Pushover, email, webhook, …) that fire on their request events, configured via a server-schema-driven form.

> **v1 scope:** the in-app inbox (bell + list) is **✂️ cut from v1** — status rides on the [request list](../04-requests/request-list.md)'s live states; revisit the inbox with [push (APNs)](../08-deferred/push-notifications.md). **[Delivery channels](delivery-channels-manage.md) (F6.3/F6.4) stay in v1** — they're how a portal user gets pinged outside the app today.

**Maps to:** a `Feature-Notifications` slice (no dedicated plan yet).
**Source surface:** `web/src/components/portal/notification-bell*.tsx`, `web/src/api/portal/inbox.ts`, `web/src/api/portal/notifications.ts`, `web/src/hooks/portal/{use-inbox,use-user-notifications}.ts`, `web/src/routes/requests/notification-channel*.tsx`, the shared `web/src/components/notifications/notification-dialog.tsx`.

## Features

- [ ] ✂️ [Inbox bell & unread indicator](inbox-bell-badge.md) — header bell, unread badge *(cut from v1)*
- [ ] ✂️ [Inbox list & read-state](inbox-list-read-state.md) — recent notifications, mark-read, deep-link *(cut from v1)*
- [ ] [Manage delivery channels](delivery-channels-manage.md) — list, enable/disable, test, delete
- [ ] [Channel editor (schema-driven form)](channel-editor-schema-form.md) — add/edit via the server notifier schema

## Notes

- Notification **types** are `approved / denied / available` (a request lifecycle), each with a typed icon on web.
- The web's in-form channel **Test** button mistakenly targets the *admin* test endpoint (likely 401s with a portal token) — captured in [manage delivery channels](delivery-channels-manage.md).
- Delivery channels are configured from the [Settings](../07-settings/settings-shell.md) Notifications tab.
