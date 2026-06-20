---
epic: 02-authentication
status: unrefined
type: feature
v1: true
plan: "Plan 1"
---

# Sign out

**Intent:** Let the user explicitly log out, clearing their session and cached personal data, and return to the sign-in screen.

## Summary
Calls the logout endpoint and disposes the stored token and in-memory caches, returning to PIN entry. Because the family may share a device, sign-out should also consider clearing cached imagery so one user's posters don't bleed into another's session.

## In scope
- A logout action (from Settings, and wherever else appropriate).
- Clear the Keychain token + cached query state; return to the auth screen.
- Optionally clear the Nuke image cache on a shared device.

## Source of truth (web portal)
- `POST /api/v1/requests/auth/logout` (success clears the local session; server may invalidate the token).
- Settings area: "Settings shell, navigation, and logout". Already built: **Plan 1** `AuthStore.signOut`.

## iOS notes
- The JWT has no refresh; treat logout primarily as client-side disposal.
- Clearing the image cache matters mainly for shared family devices — see [design system](../01-foundations/design-system-image-loading.md).

## Open questions
- [ ] Does `/auth/logout` actually revoke the token server-side, or is it client-side disposal only?
- [ ] Clear the image cache on every logout, or only when a different user signs in?

## Dependencies
- [Session persistence](session-persistence-keychain.md), [design system & image loading](../01-foundations/design-system-image-loading.md).
