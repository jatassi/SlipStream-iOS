---
epic: 01-foundations
status: partial
type: feature
v1: true
plan: "Plan 1 (auth subset; grows per feature)"
---

# Portal API client (Bearer JWT + base path + error model)

> **Status (2026-06-20):** ✅ **Infrastructure complete** — Plan 1 (`d268544`) delivered the auth slice (`PortalAPIClient` + `APIClientError` + `AuthAPI`). The F1.2 finish plan ([`docs/superpowers/plans/2026-06-20-portal-api-client.md`](../../plans/2026-06-20-portal-api-client.md)) added the reusable plumbing: multi-base targeting via `APIBase` (`portal` / `metadata` / public `status`), a public `send`/`sendNoContent` request surface with `204`/empty handling, and a central `onUnauthorized` hook that fires on a token-bearing `401`. The per-resource endpoint methods (search/library/requests/inbox/notifications) are **not** part of F1.2 — they grow in their own feature plans (F3.x/F4.x/F6.x) on top of this client.

**Intent:** Give every feature one HTTP client that roots calls at `/api/v1/requests`, attaches the stored JWT, and parses responses/errors uniformly — so feature code never re-implements networking.

## Summary
Mirrors the web `portalFetch` wrapper: build URLs from the persisted base + `/api/v1/requests` + path, attach `Authorization: Bearer <jwt>` when present, decode success bodies, treat `204` as empty, and map non-2xx to a typed error reading the server's `{ message?, error? }` body. A `401` from any call emits an "unauthorized" signal consumed by the [session-expiry handler](../02-authentication/session-expiry-auto-logout.md).

## In scope
- Base-path + URL construction; `Bearer` header injection.
- Success decode; `204`/empty handling; typed error mapping (`{message?, error?}`).
- Central `401` hook → notify the auth layer.

## Source of truth (web portal)
- `web/src/api/portal/client.ts` (the `portalFetch` client, base path, 401 → `auth:unauthorized`).
- `web/src/api/portal/index.ts` (per-resource clients build on it).
- Already built (auth subset): **Plan 1** `PortalAPIClient` + `APIClientError`. This stub is the full-surface extension (search/library/requests/inbox/notifications).

## iOS notes
- `URLSession` + async/await; extend Plan 1's client rather than starting over.
- Emit the 401 signal once, centrally (e.g. a `NotificationCenter` post or an async stream) rather than per-call.
- The portal JWT carries `aud: "portal"`, `role: "user"` (issuer `slipstream-portal`, 30-day expiry). Admin-only routes reject it with **401** (not 403). The same token is also accepted by the shared `/api/v1/metadata/*` group and the public `/api/v1/status` — both on base `/api/v1`, outside the `/api/v1/requests` portal base — so the client should be able to target those two bases too.

## Open questions
- [x] ~~Distinguish `403` from `401` for a portal token on an admin route?~~ **Resolved: admin routes return `401`** ("invalid or expired token") for a portal token — treat as the standard unauthorized path.
- [x] ~~Any retry/backoff policy for transient network errors, or fail fast?~~ **Resolved: fail fast** — no retry/backoff, mirroring the web `portalFetch` (`web/src/api/portal/client.ts`). A transport error maps to `APIClientError.transport(_)` and surfaces immediately; polling features re-fetch on their own cadence.

## Downstream notes (surfaced in the F1.2 final review)
- **Query parameters (F3.x):** `send`/`sendNoContent` build URLs with `appendingPathComponent`, which percent-encodes `?` — a path string cannot carry a query. The web passes query strings inline (`buildQueryString` + `` `${API_BASE}${path}` ``, `web/src/api/portal/client.ts`). Search/library endpoints (F3.x) will need a `queryItems`/`URLComponents` mechanism added to the client.
- **`401` hook is per-request (F2.4):** `onUnauthorized` fires for each token-bearing `401`. The web de-dups concurrent 401s by nulling its module-global token after the first (`handleUnauthorized`, `web/src/api/portal/client.ts`); the stateless iOS client holds no token, so F2.4's consumer must make session-clear idempotent / guard re-entry.

## Dependencies
- [Codable data contract](data-contract-models.md), [session persistence](../02-authentication/session-persistence-keychain.md) (token source), [session-expiry auto-logout](../02-authentication/session-expiry-auto-logout.md).
