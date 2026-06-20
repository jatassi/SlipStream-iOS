---
epic: 02-authentication
status: unrefined
type: feature
v1: true
plan: "Plan 1"
---

# Session persistence & Keychain / Face-ID gate

**Intent:** Keep the user signed in across launches and attach their token to every call — without a refresh flow — while gating token release behind Face ID.

## Summary
Store the 30-day JWT in a biometric-gated Keychain item. On launch, load it (Face ID) and validate by fetching the profile; if valid, route to the app, otherwise to PIN entry. An auth route guard keeps unauthenticated users out of portal screens. The PIN authenticates to the server; **Face ID is only a local gate** on releasing the stored token.

## In scope
- Keychain storage of the JWT (`.userPresence`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, `deviceOwnerAuthentication`).
- Restore-on-launch: load token → validate via `GET /api/v1/requests/auth/profile` → signed-in or signed-out.
- Auth route guard around all portal screens.
- Attach `Bearer <jwt>` to every portal call (via the API client).

## Source of truth (web portal)
- Auth area: "Session Persistence & Token-Backed API Auth", "Authentication Route Guard"; `web/src/components/portal/portal-auth-guard.tsx`.
- Setup doc §6 (auth model). Already built: **Plan 1** `AuthStore` + `KeychainTokenStore` + `restore()`.

## iOS notes
- Largely **done in Plan 1** — this stub records the full intent and the route guard.
- No refresh token: on expiry, re-PIN (handled by [session-expiry](session-expiry-auto-logout.md)).

## Open questions
- [ ] Proactively decode the JWT `exp` to pre-empt failures, or stay purely reactive to 401s like the web?
- [ ] Confirm no portal endpoint secretly needs the admin auth setter (portal-only client must never set an admin token).

## Dependencies
- [Portal API client](../01-foundations/portal-api-client.md), [PIN sign-in](pin-sign-in.md), [session-expiry auto-logout](session-expiry-auto-logout.md).
