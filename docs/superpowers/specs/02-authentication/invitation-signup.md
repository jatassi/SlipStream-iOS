---
epic: 02-authentication
status: refined
type: feature
v1: true
plan: "own plan"
---

# Invitation signup (redeem invite → set PIN)

**Intent:** Let a newly invited family member redeem their invitation link, choose a 4-digit PIN, and get an active account that's immediately signed in — entirely on-device.

> ✅ **Decided: iOS supports signup.** **Free-tier nuance:** a tappable `https://…/signup?token=` *universal link* needs the Associated Domains entitlement (paid tier — the same blocker as [passkeys](../08-deferred/passkey-authentication.md)), so on the free Personal Team v1 redeems the invite via **manual link paste**. The create-PIN flow itself is unaffected.

## Summary

From a pasted invitation link, derive the server origin and token, validate the token, greet the user by the invited username, collect a new 4-digit PIN, create the account, and sign in. The flow renders **four states** mirroring the web route — no-token, validating, invalid/expired, and the create-PIN form (auto-submits at 4 digits). Invitations themselves are *created by an admin* and are out of scope.

## Decisions (resolved during brainstorming, 2026-06-20)

1. **Invite entry = paste the full link.** The pasted `https://host/signup?token=…` URL carries **both** the server origin and the token. We parse both — bootstrapping the server origin for a brand-new user who has never configured one, in a single step. A **bare token** is also accepted when a server is already configured (covers dev / re-redeem). Reached from a "Have an invitation? Sign up" affordance on the sign-in screen. No custom URL scheme (the server emits `https` links, not `slipstream://`, so a scheme would have no trigger in v1); universal links stay deferred to the paid tier.
2. **`resendInvitation` is out of v1.** The portal `POST /auth/resend` endpoint has no web consumer; on an expired/invalid invite we tell the user to ask the admin (you) for a fresh link. Matches the web; smaller surface.
3. **`expiresAt` is not displayed.** The web validates expiry server-side but never shows it. We greet by username only; no countdown.

## In scope

- Accept an invitation via **pasted link** (full URL → origin + token; bare token when a server is set).
- Validate the token; render the four state views (no-token / validating / invalid-or-expired / create-PIN).
- Create-PIN entry + auto-submit at 4 digits; establish the session (auto-sign-in) on success.

## Out of scope

- Creating / managing invitations (admin surface — stays on the web portal).
- Universal links / AASA, custom URL schemes, `resendInvitation` (see Decisions).

## Architecture

Follows the existing `AuthStore` / `PortalAPIClient` / `Feature-Auth` layering. **No new models** — `ValidateInvitationResponse`, `SignupRequest`, `SignupResponse` already exist from F1.3's contract mirror. **No new third-party deps.**

**1. SlipStreamKit — Networking.** Extend the `AuthAPI` protocol + `PortalAPIClient` with two unauthenticated calls:

- `validateInvitation(token:) async throws -> ValidateInvitationResponse` → `GET auth/validate-invitation?token=<percent-encoded>` (token is base64-URL → must be query-encoded).
- `signup(_:) async throws -> SignupResponse` → `POST auth/signup` body `{token, password}`.

The client keeps throwing `APIClientError.http(status:message:error:)`; semantic mapping happens one layer up.

**2. SlipStreamKit — `InvitationSignupStore`** (new `@MainActor @Observable`, the testable heart). Owns a phase machine mirroring the web's four states plus iOS submission state:

```swift
enum Phase: Equatable {
  case awaitingToken                 // paste screen        (web NoTokenView)
  case validating                    // spinner             (web ValidatingView)
  case invalid(InvalidReason)        // terminal/retryable  (web InvalidInvitationView)
  case ready(username: String)       // create-PIN form     (web SignupForm)
  case creatingAccount               // submitting signup
}
enum InvalidReason: Equatable { case notFound, expired, used, badToken, network(String) }
```

Methods: `submitInviteLink(_ pasted: String) async` (parse → validate) and `createAccount(pin: String) async` (signup → finalize). Holds the parsed `serverURL` + `token` **in memory**, committing them only on signup success. Depends on a `makeAuthAPI: @Sendable (URL) -> AuthAPI` factory, a `ServerConfigStore` (to read an already-configured origin for the bare-token path), and a reference to `AuthStore` (for the final session commit).

**3. SlipStreamKit — `InviteLinkParser`** (new, pure). Extracts `(origin, token)` from a pasted `https://host/signup?token=…` URL; falls back to treating the input as a bare token when it isn't a URL but a server is already configured. Pure + unit-tested.

**4. SlipStreamKit — `AuthStore.establishSession(serverURL:token:user:username:)`** (new, public). A tiny session-commit reusing signIn's existing private finalize (Keychain save, server config, last-username, `state = .signedIn`). Keeps all invitation orchestration + error mapping inside `InvitationSignupStore` while `AuthStore` stays the single session authority — signup and sign-in commit through the same code path.

**5. Feature-Auth — `InvitationSignupView`** (new), driven by `Phase`, reusing **`PINEntryField`** with the same focus-gated auto-submit-at-4 as `SignInView`. Reached from a "Have an invitation? Sign up" button on `SignInView`, presented as a **`.sheet`**. On success `AuthStore.state` flips to `.signedIn`, `AuthGateView` swaps the signed-out tree for the app shell, and the sheet tears down with it.

**6. App composition** — `SlipStreamApp.init` builds the store with the `makeAuthAPI` factory + `serverConfig` + `auth` ref already wired, injected via `.environment`.

## Data flow

Tap "Have an invitation?" → paste link → parse origin+token → `.validating` → `GET validate-invitation` → `.ready(username)` → enter 4-digit PIN → auto-submit → `.creatingAccount` → `POST signup` → `AuthStore.establishSession` → `.signedIn` → app shell.

## Error handling

- **Bad paste** (no token / unparseable, no configured server) → stay on `.awaitingToken` with an inline message (don't burn to `.invalid`).
- **validate** status map: `404`→`notFound` · `410`→`expired` · `409`→`used` · `400`→`badToken` · transport→`network` (shows **Retry**). The first three are terminal ("ask your admin for a new link").
- **signup** status map: `409`→`used` (invite consumed between validate & submit, or username taken) · `410`→`expired` → `.invalid`; transport → back to `.ready` with a transient banner, PIN cleared (mirrors `SignInView` failure behavior). Keychain save failure on `establishSession` surfaces as an error (rare), mirroring signIn.

## Source of truth (web portal)

- `web/src/routes/requests/auth/signup.tsx` (`NoTokenView`, `ValidatingView`, `InvalidInvitationView`, create-PIN; auto-submit at `pin.length === 4`; greets "Welcome, {username}!"; `expiresAt` not shown).
- `web/src/hooks/portal/use-portal-auth.ts` — `usePortalSignup` calls `storeLogin(token, user)` (signup establishes the session identically to login).
- `GET /api/v1/requests/auth/validate-invitation?token=<token>` → `{ valid, username, expiresAt }`. Errors: `400` (no token) · `404` not-found · `410` expired · `409` used.
- `POST /api/v1/requests/auth/signup` — body `{ token, password }` (PIN) → `{ token, user }` (`201 Created`). Errors: `400` · `404` · `410` · `409` (used / username already registered) · `500`.
- Server accepts any non-empty password; iOS enforces exactly 4 digits client-side. Token is base64-URL-encoded 32 bytes.

## Testing (TDD, headless `swift test` — project standard)

- `PortalAPIClient`: both new calls hit correct path / method / query-encoding and decode; error statuses → `APIClientError.http` (StubURLProtocol pattern).
- `InviteLinkParser`: full URL, trailing slash, fragment, bare token, garbage.
- `InvitationSignupStore`: parse → validate → `ready`/`invalid` per status; `createAccount` success calls `establishSession` (state `.signedIn`); signup `409` → `invalid(.used)`; transport → `ready` + error.
- `AuthStore.establishSession`: token saved, config + username set, state `.signedIn` (mirrors the existing signInSuccess test).
- **On-device:** if a real invite link is obtainable from the dev server's admin side, run the full paste → PIN → shell loop on **iPhone 17** against the live `--dev-mode` server; otherwise the unit tests are the gate (F1.5 / F2.4 precedent) plus rendering the four states (a deliberately-bad token covers `.invalid`).

## Dependencies

- [PIN sign-in](pin-sign-in.md) (`PINEntryField`, `AuthStore` session model), [Portal API client](../01-foundations/portal-api-client.md), [session persistence](session-persistence-keychain.md) (Keychain token store), [app shell & navigation](../01-foundations/app-shell-navigation.md).
