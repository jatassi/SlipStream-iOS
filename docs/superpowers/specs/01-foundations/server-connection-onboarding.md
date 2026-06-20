---
epic: 01-foundations
status: unrefined
type: feature
v1: true
plan: "Plan 1"
---

# Server connection onboarding & base URL capture

**Intent:** Let the user point the app at their SlipStream server by entering its HTTPS origin once, then persist it so every later launch and API call knows where to go.

## Summary
The web portal is served same-origin, so it never asks "which server?" — it hardcodes the path. A native app has no implicit origin, so first-run onboarding must capture the server's HTTPS base URL, validate it, and store it (non-secret) for reuse. There is **no server endpoint** for this; it's a purely client-side concern.

## In scope
- A server-URL field on the sign-in screen (HTTPS only — App Transport Security blocks plain HTTP).
- Persist the base URL across launches (non-secret store, e.g. `UserDefaults`); pre-fill it on return.
- Surface clear "can't reach server / bad URL" errors distinct from auth failures.

## Source of truth (web portal)
- Same-origin web client hardcodes `/api/v1/requests` — see `web/src/api/portal/client.ts`.
- Already partially built: **Plan 1** `SignInView` has a server-URL field and `UserDefaultsServerConfigStore`.

## iOS notes
- Reuse Plan 1's `UserDefaultsServerConfigStore`; the URL is the reverse-proxy HTTPS origin (no ATS exception needed).
- Normalize trailing slashes; reject non-`https` schemes.

## Open questions
- [ ] Validate reachability (a ping/`/status` probe) before accepting, or defer to the first real call?
- [ ] Support more than one saved server (multi-instance), or single-server only for v1?

## Dependencies
- [Portal API client](portal-api-client.md) (consumes the base URL).
