# Epic 07 — Account & Settings

The signed-in user's self-service account surface: a Settings home that organizes account controls, lets them rotate their PIN, edit their profile, reach their notification channels, and log out. No admin / user-management capability — this is the portal user's own account only.

**Maps to:** a settings slice of `Feature-Auth` / `Feature-Settings`.
**Source surface:** `web/src/routes/requests/{settings,settings-header}.tsx`, `web/src/routes/requests/use-request-settings.ts`, `web/src/components/portal/change-pin-dialog.tsx` + `use-change-pin.ts`, `web/src/api/portal/auth.ts`.

## Features

- [ ] [Settings shell & navigation](settings-shell.md) — Security / Notifications tabs, logout
- [ ] [Change PIN](change-pin.md) — 3-step verify → new → confirm wizard
- [ ] [Edit profile (username)](edit-profile.md) — optional; endpoint supports it, web doesn't wire it

## Notes

- The web settings shell has two tabs: **Security** (change PIN; passkeys when supported) and **Notifications** ([delivery channels](../06-notifications/delivery-channels-manage.md), which live in Epic 06).
- **Passkey management** would live in the Security tab but is [deferred](../08-deferred/passkey-authentication.md) (Associated Domains / paid tier).
- The account "password" *is* the 4-digit PIN — changing the PIN is a profile-password update.
