---
epic: 01-foundations
status: unrefined
type: feature
v1: true
plan: "— (beyond current plans)"
---

# System & enabled-module discovery

**Intent:** Let the app learn which media modules (movie / tv) and capabilities are enabled so it can show/hide request flows and tabs the user has no access to, instead of hardcoding movie+tv.

## Summary
`GET /api/v1/status` returns `enabledModules` + `portalEnabled` and is **public — no token required** (registered before the admin-protected group, `internal/api/routes.go:107-108`), so the iOS app can read it directly. A portal user's own *allowed* modules additionally come from their profile's `moduleSettings`. Note `/status` lives on base `/api/v1`, not the `/api/v1/requests` portal base.

## In scope
- Discover enabled modules and gate movie-vs-tv request flows + library/search tabs accordingly.
- Consume per-user `moduleSettings` (which modules this user can request).
- Surface `portalEnabled` to the [portal-disabled gate](../02-authentication/portal-disabled-gate.md).

## Source of truth (web portal)
- `GET /api/v1/status` → `SystemStatus` (base `/api/v1`, **not** `/requests`; **public / no-auth** — `internal/api/routes.go:107-108`, handler `internal/api/handlers_system.go:27-69`).
- `GET /api/v1/requests/auth/profile` → `PortalUser.moduleSettings` (portal-token-safe).
- App-shell area polls `/status` at 30s for `portalEnabled` + modules.

## iOS notes
- Read `enabledModules` + `portalEnabled` from the public `GET /api/v1/status`; use per-user `moduleSettings` (from `/auth/profile`) to further narrow what *this* user may request.
- `/status` is the discovery source for `portalEnabled` precisely because it stays reachable when `/api/v1/requests/*` is not — that group is gated by `PortalEnabled()` (`503` when the portal is off).
- Model module type as an enum with raw values `{ "movie", "tv" }`.

## Open questions
- [x] ~~Does a portal JWT succeed on `GET /api/v1/status`?~~ **Resolved: yes — `/status` is fully public** (no token needed at all).
- [ ] Confirm the module-type string set is exactly `{movie, tv}` and stable (used as enum raw values).

## Dependencies
- [Portal API client](portal-api-client.md), [Codable data contract](data-contract-models.md).
