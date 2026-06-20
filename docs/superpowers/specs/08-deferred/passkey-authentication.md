---
epic: 08-deferred
status: unrefined
type: feature
v1: false
plan: "Deferred (paid tier)"
---

# Passkey authentication & management (WebAuthn)

**Intent:** Passwordless, biometric sign-in and passkey management as a faster, more secure alternative to the username + 4-digit PIN.

> ⛔ **Deferred for v1.** Native passkeys require the **Associated Domains** entitlement — a managed capability available only through the **paid Apple Developer Program** — plus an `apple-app-site-association` file and server-side WebAuthn RP config for the app's associated domain. On iOS v1, the **Face-ID-gated Keychain JWT is the substitute** for passkeys. Revisit if/when the paid tier is taken.

## Summary
The web portal supports the full passkey lifecycle, which an un-deferred iOS build would mirror with `AuthenticationServices`:
- **Login** — `ASAuthorizationController` assertion (begin → finish).
- **Register** — PIN-gated enrollment of a named passkey (begin → finish).
- **Manage** — list / rename / delete credentials in the Security tab.
- **Promotion** — a post-login nudge for non-admin users with zero passkeys.
- **Deep-link** — open the settings screen with the registration form expanded.

## Source of truth (web portal)
- `web/src/api/portal/passkey.ts`; `web/src/components/portal/passkey-*` + `use-passkey-*`; `web/src/components/portal/passkey-deep-link.ts` (`#new-passkey` hash).
- Endpoints (all under `/api/v1/requests`): `POST /auth/passkey/login/{begin,finish}`, `POST /auth/passkey/register/{begin,finish}`, `GET/PUT/DELETE /auth/passkey/credentials[/{id}]`.

## iOS notes
- `ASAuthorizationPlatformPublicKeyCredentialProvider`; base64url-decode/encode the WebAuthn JSON (challenge/credential IDs ↔ `Data`); `challengeId` is a **query param** on `finish`, the credential JSON in the body.
- Requires the server's RP ID/origin to accept the app's associated domain (app-attested passkeys).

## Open questions
- [ ] Does the server's WebAuthn config accept a native app's associated domain (same RP as the web origin)?
- [ ] Is passkey **login** even wanted on iOS given the app already stores a JWT behind Face ID, or only passkey *management*?
- [ ] Should the "don't show again" promotion preference sync per-account or stay device-local?

## Dependencies
- [Session persistence & Keychain](../02-authentication/session-persistence-keychain.md), [settings shell](../07-settings/settings-shell.md), [app shell](../01-foundations/app-shell-navigation.md) (deep link).
