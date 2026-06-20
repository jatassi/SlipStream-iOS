---
epic: 07-settings
status: unrefined
type: feature
v1: true
plan: "own plan"
---

# Change PIN

**Intent:** Let the user rotate their 4-digit account PIN securely by proving they know the current one, choosing a new one, and confirming it.

## Summary
A three-step wizard: verify the current PIN, enter a new PIN, confirm it. Verification calls `verify-pin`; persistence is a profile-password update (the PIN *is* the account password). The auth store / profile cache update on success.

## In scope
- 3-step verify-current → new → confirm flow.
- Verify the current PIN; persist the new one; update the session.
- Error handling for wrong current PIN / mismatch.

## Source of truth (web portal)
- `web/src/components/portal/change-pin-dialog.tsx`, `use-change-pin.ts`.
- `POST /api/v1/requests/auth/verify-pin` — body `{ pin }` → `{ valid: boolean }`.
- `PUT /api/v1/requests/auth/profile` — body `{ password: <newPin> }` → updated `PortalUser`.

## iOS notes
- Reuse the 4-digit OTP field from [PIN sign-in](../02-authentication/pin-sign-in.md).
- The web collapses "incorrect current PIN" and network errors into one message — iOS could distinguish them.

## Open questions
- [ ] Does the backend enforce PIN constraints (length 4, numeric, must differ from current), or is that client-side only?
- [ ] Server-side rate limiting / lockout on repeated `verify-pin` failures to surface?
- [ ] Distinguish "incorrect current PIN" from a transient network error?

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [settings shell](settings-shell.md).
