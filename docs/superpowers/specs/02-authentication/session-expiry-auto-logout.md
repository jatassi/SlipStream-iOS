---
epic: 02-authentication
status: done
type: feature
v1: true
plan: "2026-06-20-session-expiry-auto-logout"
---

# Session-expiry / 401 auto-logout

> **Status (2026-06-20):** ✅ **Done** — [plan](../../plans/2026-06-20-session-expiry-auto-logout.md). Plan 1 delivered the restore-path 401; F2.4 added the central handler: a `SessionExpiry` mediator funnels every token-bearing 401 (poll + non-poll) → pause the poller + sign out, gated on `state == .signedIn`. `AuthStore.signOut()` made idempotent. **Silent** return to PIN (no messaging); both expired/revoked 401s share one path.

**Intent:** Gracefully recover when the 30-day token expires or is rejected mid-session, instead of leaving the user stuck on a broken screen.

## Summary
A `401` from any portal call triggers a client-side logout and a return to PIN entry. Because there's no refresh endpoint, recovery *is* "re-enter the PIN." Polling should pause immediately on the first `401` so a burst of failed polls doesn't pile up before the logout takes effect.

## In scope
- Central `401` handler (fed by the API client) → clear token, sign out, route to PIN.
- Pause/stop the poller on the first `401`.
- Optional explicit "session expired" messaging vs a silent return to login.

## Source of truth (web portal)
- Auth area "Session-Expiry / Unauthorized Auto-Logout"; App-shell "Global Session-Expiry (401) Handling".
- Web mechanism: a global `auth:unauthorized` listener in `web/src/components/layout/use-layout-effects.ts`.
- Already partial: **Plan 1** `restore()` 401 path; the poller is its own plan ([F1.5](../01-foundations/polling-engine.md)).

## iOS notes
- Subscribe to the API client's 401 signal centrally; pause the [poller](../01-foundations/polling-engine.md) at once.

## Open questions
- [x] Explicit "session expired" screen, or silently show the PIN screen (web shows nothing extra)? → **Silent** (match web); the remembered username (F2.1) keeps re-entry one PIN away.
- [x] Distinguish 401-expired vs 401-revoked, or treat both as "return to login"? → **Treat both the same** — a portal client can't tell them apart (both are a bare `401` on a stateless JWT).

## Dependencies
- [Portal API client](../01-foundations/portal-api-client.md), [polling engine](../01-foundations/polling-engine.md), [session persistence](session-persistence-keychain.md).
