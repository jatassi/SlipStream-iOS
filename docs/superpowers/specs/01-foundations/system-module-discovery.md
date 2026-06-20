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
The web reads `GET /api/v1/status` (on the admin base path) for `enabledModules` + `portalEnabled`. A portal user's own allowed modules also come from their profile's `moduleSettings`. A key unknown is whether a **portal** JWT may call `/status` at all — if not, the app must rely solely on `moduleSettings`.

## In scope
- Discover enabled modules and gate movie-vs-tv request flows + library/search tabs accordingly.
- Consume per-user `moduleSettings` (which modules this user can request).
- Surface `portalEnabled` to the [portal-disabled gate](../02-authentication/portal-disabled-gate.md).

## Source of truth (web portal)
- `GET /api/v1/status` → `SystemStatus` (base `/api/v1`, **not** `/requests`; admin-client in web).
- `GET /api/v1/requests/auth/profile` → `PortalUser.moduleSettings` (portal-token-safe).
- App-shell area polls `/status` at 30s for `portalEnabled` + modules.

## iOS notes
- Prefer the portal-safe `moduleSettings` if `/status` returns 401/403 for portal tokens.
- Model module type as an enum with raw values `{ "movie", "tv" }`.

## Open questions
- [ ] **Does a non-admin portal JWT succeed on `GET /api/v1/status`, or 401/403?** Determines the whole approach (needs an on-device/server check).
- [ ] Is a portal-scoped capability endpoint planned (so the app needn't depend on the admin `/status`)?
- [ ] Confirm the module-type string set is exactly `{movie, tv}` and stable.

## Dependencies
- [Portal API client](portal-api-client.md), [Codable data contract](data-contract-models.md).
