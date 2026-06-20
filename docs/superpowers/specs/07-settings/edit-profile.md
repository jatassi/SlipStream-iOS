---
epic: 07-settings
status: unrefined
type: feature
v1: true
plan: "— (optional)"
---

# Edit profile (username)

**Intent:** Let the user edit their account profile — specifically their username.

> **Optional / scope decision:** the profile-update endpoint supports a `username` change, but the **web UI only ever sends `password`** (the PIN). Decide whether iOS exposes username editing at all.

## Summary
`UpdateProfileRequest` supports both `username` and `password`. The web only wires the password path (change-PIN); username change is unwired despite the endpoint supporting it. `getProfile` is available to refresh the current profile.

## In scope
- Edit username via `PUT /api/v1/requests/auth/profile` (`{ username }`); reflect it in the session.
- Refresh via `GET /api/v1/requests/auth/profile` if needed.

## Source of truth (web portal)
- `web/src/api/portal/auth.ts` `updateProfile` (`UpdateProfileRequest.username`), `getProfile`.
- `PUT /api/v1/requests/auth/profile`; `GET /api/v1/requests/auth/profile`.

## iOS notes
- Username change has no web consumer — confirm it's actually permitted for portal users before building UI.

## Open questions
- [ ] Is username editable for portal users in practice, or effectively admin-only?
- [ ] Username uniqueness / validation rules?

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [settings shell](settings-shell.md).
