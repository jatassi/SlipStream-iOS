---
epic: 06-notifications
status: unrefined
type: feature
v1: true
plan: "—"
---

# Manage delivery channels

**Intent:** Let the user manage their own notification delivery channels so they get pinged when their requests are approved, denied, or become available.

## Summary
A list of the user's configured channels (Discord / Telegram / ntfy / Pushover / email / webhook / …) with on/off state. From the list the user can enable/disable a channel inline, send a test ping, and delete it. Adding/editing a channel is the [schema-driven editor](channel-editor-schema-form.md).

## In scope
- List channels (`GET /api/v1/requests/notifications`).
- Enable/disable inline (a full `PUT /notifications/{id}` with the flipped `enabled`).
- Send a test (`POST /notifications/{id}/test`).
- Delete (`DELETE /notifications/{id}`).

## Source of truth (web portal)
- `web/src/api/portal/notifications.ts`; `web/src/routes/requests/notification-channels-card.tsx`, `notification-channel-row.tsx`; `web/src/hooks/portal/use-user-notifications.ts`.

## iOS notes
- ⚠️ The web dialog's **in-form Test** button does *not* use the portal test endpoint — it falls back to the **admin** `apiFetch` test (`POST /api/v1/notifications/test`), which likely 401s with a portal token. iOS should either omit in-form test or use the portal `/notifications/{id}/test` (saved-channel) endpoint.
- A native **APNs device-push channel** the web lacks is a [deferred](../08-deferred/push-notifications.md) possibility (needs a server endpoint + paid tier).

## Open questions
- [ ] Which notifier types are portal-usable vs admin-only (e.g. Plex, custom_script)?
- [ ] Is there a per-user cap on channels?
- [ ] Does a portal "test unsaved config" endpoint exist, or only test-saved?

## Dependencies
- [Channel editor (schema-driven)](channel-editor-schema-form.md), [Codable data contract](../01-foundations/data-contract-models.md), [settings shell](../07-settings/settings-shell.md).
