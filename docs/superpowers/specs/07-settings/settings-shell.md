---
epic: 07-settings
status: unrefined
type: feature
v1: true
plan: "—"
---

# Settings shell & navigation

**Intent:** Give the signed-in user a single Settings home with a clear way back to the app and a destructive Log Out action, organizing account controls under Security vs Notifications.

## Summary
A tabbed settings surface: **Security** (change PIN; passkeys when enabled) and **Notifications** (delivery channels). Hosts the Log Out action and a back affordance to the app.

## In scope
- Settings home with Security / Notifications sections.
- Back affordance; Log Out (`POST /api/v1/requests/auth/logout`).
- Hosts [change PIN](change-pin.md), [edit profile](edit-profile.md), and the [delivery-channels](../06-notifications/delivery-channels-manage.md) entry (passkeys section is [deferred](../08-deferred/passkey-authentication.md)).

## Source of truth (web portal)
- `web/src/routes/requests/settings.tsx`, `settings-header.tsx`, `use-request-settings.ts`.

## iOS notes
- Settings as a tab or a pushed screen (ties into [app shell](../01-foundations/app-shell-navigation.md) — open question there about tab vs toolbar button).

## Open questions
- [ ] Does `/auth/logout` revoke the JWT server-side, or is logout purely client-side disposal (no-refresh JWT suggests the latter)?
- [ ] Where should the Back affordance land — the tab the user came from, or a fixed home?

## Dependencies
- [Change PIN](change-pin.md), [edit profile](edit-profile.md), [delivery channels](../06-notifications/delivery-channels-manage.md), [sign out](../02-authentication/sign-out.md).
