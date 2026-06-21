---
epic: 02-authentication
status: done
type: feature
v1: true
plan: "Plan 1"
---

# PIN sign-in (username + 4-digit PIN)

> **Status (2026-06-21):** ✅ **Done** — Plan 1 (`d268544`) delivered core sign-in; F2.1's own pass added the remaining pieces: a remembered last-username collapsed into a chip with **Switch User** (`LastUsernameStore` in `SlipStreamKit`, persisted on successful sign-in only), a 4-slot masked `PINEntryField` (number pad, dot mask, active-slot highlight), and **OTP auto-submit** the moment the PIN completes with a username present (focus-gated so a pre-filled dev PIN never auto-logs-in), clearing the PIN on failure. Kit logic headless via `swift test`; full sign-in / remembered-chip / Switch User / auto-submit loop verified on iPhone 17 against the live dev server.

**Intent:** Let a returning user sign in with their username and 4-digit PIN to obtain a portal JWT and land in the requests experience.

## Summary
A 4-slot masked PIN entry that **auto-submits** the moment all four digits are entered and a username is present (with a Sign-In button as fallback). The screen **remembers the last successful username**, collapsing it into a chip with a "Switch User" button so returning users only type their PIN. On the wire the PIN is sent as the `password` field.

## In scope
- Username + 4-digit numeric, masked PIN entry; auto-submit on completion.
- Remembered last username with a "Switch User" affordance to clear and re-enter.
- Error handling: invalid credentials → clear the PIN, keep the username, show an error.
- Land portal users on the requests experience after success.

## Source of truth (web portal)
- `web/src/routes/requests/auth/login.tsx` (`useLoginPage`: `localStorage 'slipstream_last_username'`, Switch User, OTP auto-submit).
- `POST /api/v1/requests/auth/login` — body `{ username, password }` (`password` = the PIN) → `{ token, user, isAdmin }`.
- Already built (MVP): **Plan 1** `SignInView`.

## iOS notes
- Custom 4-digit secure OTP field (`.numberPad`, masked); persist the last username (UserDefaults/Keychain).
- Map the web toast to an inline error label.
- Treat admin accounts the same as portal users (land on requests; ignore the web's admin-redirect branch).

## Open questions
- [ ] Hard-restrict input to digits client-side, and surface any server PIN-attempt lockout?
- [ ] Should an `isAdmin` account behave identically to a portal user on iOS?

## Dependencies
- [Portal API client](../01-foundations/portal-api-client.md), [session persistence](session-persistence-keychain.md).
