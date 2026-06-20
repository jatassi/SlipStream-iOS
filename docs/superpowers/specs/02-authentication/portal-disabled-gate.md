---
epic: 02-authentication
status: unrefined
type: feature
v1: true
plan: "—"
---

# Portal-disabled server gate

**Intent:** When the server administrator has turned the external requests portal off, show a clear "disabled" message instead of any auth or app UI.

## Summary
The server exposes a `portalEnabled` flag (on the system/status endpoint). When it's `false`, the whole portal — including the pre-auth login screen — is replaced by a disabled state. This must work *before* the user is authenticated, so the status endpoint has to be callable without a token.

## In scope
- Read `portalEnabled`; when `false`, render a disabled view in place of auth/app UI.
- Make the gate work on the pre-auth login/signup screens.

## Source of truth (web portal)
- Auth area "Portal-Disabled Server Gate"; App-shell "Portal Auth Guard & Disabled-Portal Gate".
- `GET /api/v1/status` exposes `portalEnabled` (read via `useStatus()/usePortalEnabled()`); web shows `PortalDisabledView`.

## iOS notes
- Depends on resolving the exact status endpoint and confirming it's unauthenticated-readable — ties into [system & module discovery](../01-foundations/system-module-discovery.md).

## Open questions
- [ ] Which exact endpoint serves `portalEnabled`, and is it callable **without** a valid token (so the gate works on the login screen)?

## Dependencies
- [System & module discovery](../01-foundations/system-module-discovery.md), [Portal API client](../01-foundations/portal-api-client.md).
