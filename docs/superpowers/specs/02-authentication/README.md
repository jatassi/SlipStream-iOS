# Epic 02 — Authentication & Session

Everything between "app launched" and "authenticated portal user": sign in with a 4-digit PIN, persist the 30-day JWT behind Face ID, restore the session on launch, sign out, recover gracefully when the token expires, onboard via an invitation link, and respect a server that has the portal switched off.

The portal credential is **username + 4-digit PIN → 30-day JWT (no refresh)**. The PIN authenticates to the server; Face ID is only a *local* gate on releasing the stored token. Passkey login (which the web also offers) is **[deferred](../08-deferred/passkey-authentication.md)** — it needs the Associated Domains entitlement.

**Maps to:** `Feature-Auth` + `SlipStreamKit` auth core · **Plan 1** builds the core (in progress); the rest (signup, disabled-gate) are each their own plan.
**Source surface:** `web/src/routes/requests/auth/{login,signup}.tsx`, `web/src/api/portal/auth.ts`, `web/src/hooks/portal/use-portal-auth.ts`, `web/src/components/portal/portal-auth-guard.tsx`, `web/src/components/layout/use-layout-effects.ts`.

## Features

- [ ] [PIN sign-in](pin-sign-in.md) — username + 4-digit PIN, remembered username, OTP auto-submit
- [ ] [Session persistence & Keychain/Face-ID](session-persistence-keychain.md) — store/restore the JWT, auth route guard
- [ ] [Sign out](sign-out.md) — clear session + cached personal data
- [ ] [Session-expiry / 401 auto-logout](session-expiry-auto-logout.md) — recover from an expired/rejected token
- [ ] [Invitation signup](invitation-signup.md) — redeem an invite link, set a PIN (iOS v1; manual token entry on the free tier)
- [ ] [Portal-disabled server gate](portal-disabled-gate.md) — clear blocked state when the portal is off

## Notes

- **Plan 1 already builds** the core: `AuthStore` (sign-in / restore / sign-out), `KeychainTokenStore`, `PortalAPIClient.login/profile`, and `SignInView`. These stubs capture the *full* web behavior (remembered-username UX, the four signup state views, the disabled gate) that goes beyond Plan 1's MVP.
- **Out of scope:** creating invitations / managing users (admin surface).
