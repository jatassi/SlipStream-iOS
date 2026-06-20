---
epic: 02-authentication
status: unrefined
type: feature
v1: true
plan: "— (scope TBD)"
---

# Invitation signup (redeem invite → set PIN)

**Intent:** Let a newly invited family member redeem their invitation link, choose a 4-digit PIN, and get an active account that's immediately signed in.

> **Scope decision needed:** onboarding may be expected to happen on the **web** portal, leaving iOS login-only. Resolve before building (see Open questions).

## Summary
From an invitation token (carried in a link), validate the token, greet the user by the invited username, collect a new 4-digit PIN, create the account, and sign in. The web route renders **four distinct states**: no token provided, validating (spinner), invalid/expired, and the create-PIN form (which auto-submits at 4 digits). Invitations themselves are *created by an admin* and are out of scope.

## In scope
- Accept an invitation token (deep link / pasted link).
- Validate the token; render the four state views (no-token / validating / invalid-or-expired / create-PIN).
- Create-PIN entry + submit; auto-sign-in on success.

## Source of truth (web portal)
- `web/src/routes/requests/auth/signup.tsx` (`NoTokenView`, `ValidatingView`, `InvalidInvitationView`, create-PIN; auto-submit at `pin.length === 4`).
- `GET /api/v1/requests/auth/validate-invitation?token=<token>` → `{ valid, username, expiresAt }`.
- `POST /api/v1/requests/auth/signup` — body `{ token, password }` (PIN) → `{ token, user }`.

## iOS notes
- Universal-link/deep-link entry for the invite token; define the fallback when the app isn't installed (App Store → deferred deep link).
- `resendInvitation` (`/auth/resend`) exists on the portal API but has no portal UI consumer — scope in or out deliberately.

## Open questions
- [ ] **Does iOS support invitation signup at all, or is onboarding web-only and iOS login-only?**
- [ ] Show the invitation's `expiresAt` as a countdown, or just valid/invalid?
- [ ] Deep-link fallback when the app isn't installed.

## Dependencies
- [PIN sign-in](pin-sign-in.md), [Portal API client](../01-foundations/portal-api-client.md), [app shell & navigation](../01-foundations/app-shell-navigation.md) (deep linking).
