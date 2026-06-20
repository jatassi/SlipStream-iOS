---
epic: 06-notifications
status: unrefined
type: feature
v1: true
plan: "own plan"
---

# Channel editor (schema-driven form)

**Intent:** Let the user add or edit a notification delivery channel by picking a provider type and filling provider-specific settings, named and scoped to which request events fire it.

## Summary
The editor is driven by a **server schema**: `GET /api/v1/requests/notifications/schema` returns the available notifier types and their field definitions, which the form renders dynamically (including secret/password fields). The user names the channel and toggles which of the three portal request events fire it (`onApproved` / `onDenied` / `onAvailable`). Create is `POST`, edit is `PUT`. On web this reuses the shared admin `NotificationDialog`, discarding admin-only fields — so the **dynamic-form rendering from a server schema is a sizeable iOS build** with its own field-type handling.

## In scope
- Fetch the notifier schema; render provider-specific fields dynamically (incl. secrets).
- Channel name; the three event toggles (`onApproved` / `onDenied` / `onAvailable`).
- Create (`POST /notifications`) and edit (`PUT /notifications/{id}`).

## Source of truth (web portal)
- `web/src/routes/requests/use-request-settings.ts` (`portalEventGroups`, `extractPortalEvents`, `toNotificationForDialog`).
- `web/src/components/notifications/notification-dialog.tsx` (shared with admin).
- `web/src/api/portal/notifications.ts` `getSchema` / `create` / `update`; `GET /notifications/schema`, `POST /notifications`, `PUT /notifications/{id}`.

## iOS notes
- A dynamic SwiftUI form from `NotifierSchema[]` (text / secret / boolean / select field types) — schema cached ~24h on web.
- Secrets may be redacted on `GET` — define how edit re-submits without re-entry.

## Open questions
- [ ] What notifier set does `/notifications/schema` return for portal users (webhook only? email? Discord/Telegram?)?
- [ ] Are secret fields returned on edit or masked (and how to handle re-submission)?
- [ ] Need the single-get `GET /notifications/{id}`, or is the cached list row enough (as web uses)?

## Dependencies
- [Manage delivery channels](delivery-channels-manage.md), [Codable data contract](../01-foundations/data-contract-models.md).
