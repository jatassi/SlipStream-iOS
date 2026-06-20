---
epic: 08-deferred
status: unrefined
type: feature
v1: false
plan: "Deferred (paid tier)"
---

# Push notifications (APNs)

**Intent:** Deliver real push notifications ("your movie is ready") for request lifecycle events, even when the app isn't open.

> ⛔ **Deferred for v1.** Real push needs **APNs**, which requires the paid Apple Developer Program. v1 instead surfaces status by **polling while foregrounded** plus the in-app [inbox](../06-notifications/inbox-list-read-state.md). Revisit with the paid tier.

## Summary
When un-deferred, the app would register for APNs and (most naturally) expose an **APNs device-push delivery channel** alongside the existing notification channels — which would require a **new server endpoint** outside the current notifier schema, since the web has no device-push channel today.

## In scope (when un-deferred)
- APNs registration + device token management.
- A server-side device-push notification channel for request events (approved / denied / available).
- Deep-link from a push into the related request.

## Source of truth (web portal)
- Setup doc §9 (deferred). Would extend the [delivery channels](../06-notifications/delivery-channels-manage.md) model with a device-push type.

## iOS notes
- Needs the paid program + server APNs support; ties into the notification-channel schema.

## Open questions
- [ ] Does/will the server support APNs and a device-push endpoint?
- [ ] Per-device token lifecycle (register/refresh/revoke on sign-out).

## Dependencies
- [Manage delivery channels](../06-notifications/delivery-channels-manage.md).
