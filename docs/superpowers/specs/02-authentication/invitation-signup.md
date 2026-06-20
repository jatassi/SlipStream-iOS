---
epic: 02-authentication
status: unrefined
type: feature
v1: true
plan: "own plan"
---

# Invitation signup (redeem invite → set PIN)

**Intent:** Let a newly invited family member redeem their invitation link, choose a 4-digit PIN, and get an active account that's immediately signed in.

> ✅ **Decided: iOS supports signup.** Family can onboard entirely on-device. **Free-tier nuance:** a tappable `https://…/signup?token=` *universal link* needs the Associated Domains entitlement (paid tier — the same blocker as [passkeys](../08-deferred/passkey-authentication.md)), so on the free Personal Team v1 redeems the invite via **manual token entry / paste** (or a custom URL scheme). The create-PIN flow itself is unaffected.

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
- **Free tier:** redeem via manual token entry / paste (or a custom URL scheme) — universal links (AASA) are paid-tier-gated. On the paid tier, add a universal-link entry + an app-not-installed → App Store fallback.
- `resendInvitation` (`/auth/resend`) exists on the portal API but has no portal UI consumer — scope in or out deliberately.

## Open questions
- [x] ~~Does iOS support invitation signup, or is it web-only?~~ **Resolved: iOS supports it** (free tier via manual token entry; universal links deferred to paid tier).
- [ ] Show the invitation's `expiresAt` as a countdown, or just valid/invalid?
- [ ] Token-entry UX on the free tier — paste the whole link, paste just the token, or a custom URL scheme?

## Dependencies
- [PIN sign-in](pin-sign-in.md), [Portal API client](../01-foundations/portal-api-client.md), [app shell & navigation](../01-foundations/app-shell-navigation.md) (deep linking).
