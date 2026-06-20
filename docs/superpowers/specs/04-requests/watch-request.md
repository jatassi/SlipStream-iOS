---
epic: 04-requests
status: unrefined
type: feature
v1: true
plan: "own plan"
---

# Watch / unwatch another user's request

**Intent:** Let a household member follow a request they didn't create (e.g. something a family member asked for) so they can track its progress without owning it.

## Summary
`POST` / `DELETE /api/v1/requests/{id}/watch` start/stop watching another user's request. Watching is most likely what feeds a user's [notification delivery channels](../06-notifications/delivery-channels-manage.md) (approved / denied / available). A `getWatchers` endpoint exists but has no web UI consumer.

## In scope
- Watch / unwatch toggle on requests the user doesn't own.
- Reflect the watching state in the card / detail.
- Decide whether to surface watcher counts/names (`getWatchers`).

## Source of truth (web portal)
- `web/src/api/portal/requests.ts` `watch` / `unwatch` / `getWatchers`.
- `POST /api/v1/requests/{id}/watch`; `DELETE /api/v1/requests/{id}/watch`; `GET /api/v1/requests/{id}/watchers` → `number[]` (unused on web).

## iOS notes
- Watching likely controls who gets notified — confirm the link to notification channels before wiring UI copy.

## Open questions
- [ ] What does watching actually *do* (drive notifications? just tracking?) — confirm the notification linkage.
- [ ] Surface watcher counts/names via `getWatchers`, or leave it unused as on web?

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [notification delivery channels](../06-notifications/delivery-channels-manage.md).
