# Epic 01 — Foundations & App Shell

The platform layer every other feature stands on: a token-authenticated HTTP client, the Codable data contract mirroring the server, capability discovery, the interval-polling engine that gives the portal its near-real-time feel, the navigation shell, and the design-system + image-loading primitives.

This isn't user-facing on its own — it's the contract and chrome the rest of the app composes against.

**Maps to:** `SlipStreamKit` + `App` shell + `DesignSystem` packages. **Plan 1** (in progress) builds the foundation + auth core + app skeleton; the rest are each their own plan.
**Source surface:** `web/src/api/portal/client.ts`, `web/src/api/portal/index.ts`, `web/src/types/portal.ts`, `web/src/components/portal/portal-layout.tsx` + `portal-header.tsx`, `web/src/hooks/portal/*`, `web/src/stores/ui.ts`.

## Features

- [ ] [Server connection onboarding](server-connection-onboarding.md) — capture & persist the HTTPS server origin (native-only; no web equivalent)
- [ ] [Portal API client (Bearer JWT + base path + errors)](portal-api-client.md) — one typed client rooted at `/api/v1/requests`
- [ ] [Codable data contract](data-contract-models.md) — Swift mirrors of `portal.ts`; admin-only types excluded
- [ ] [System & enabled-module discovery](system-module-discovery.md) — which modules (movie/tv) and capabilities are on
- [ ] [Real-time polling engine](polling-engine.md) — shared interval poller; no websockets
- [ ] [App shell & primary navigation](app-shell-navigation.md) — Home/Search/Library/Settings chrome, adaptive layout
- [ ] [Design system & image loading](design-system-image-loading.md) — Nuke posters, adaptive grid, skeletons, empty/error states

## Notes

- **Plan 1** (in progress) builds the networking/auth core (`PortalAPIClient`, `APIClientError`, the auth-subset models) and the app skeleton. The remaining foundation features — module discovery, polling engine, design system, full nav shell — are each their own plan (written at refinement). The stubs here describe the full portal surface those plans grow into.
- The portal has **no websocket** for portal tokens (the server `/ws` is admin-audience only); real-time is polling. The web app's live download strip is actually WebSocket-fed (`queue:state`) with client-side matching — see [Epic 05 · request↔download matching](../05-downloads/download-request-matching.md).
- One contract subtlety: the rich media-detail screen pulls **extended metadata from a second base path** (`/api/v1/metadata/*`, base `/api/v1`, not `/api/v1/requests`). Confirmed a **portal token is authorized** there (the `/metadata` group uses `AnyAuth()`) — see [Epic 03](../03-discovery/media-detail-screen.md). So the API client should support this second base too.
