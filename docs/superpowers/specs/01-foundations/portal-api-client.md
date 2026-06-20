---
epic: 01-foundations
status: unrefined
type: feature
v1: true
plan: "Plan 1 (extended in 2–4)"
---

# Portal API client (Bearer JWT + base path + error model)

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

## Open questions
- [ ] Distinguish `403` (portal token hitting an admin route) from `401`?
- [ ] Any retry/backoff policy for transient network errors, or fail fast?

## Dependencies
- [Codable data contract](data-contract-models.md), [session persistence](../02-authentication/session-persistence-keychain.md) (token source), [session-expiry auto-logout](../02-authentication/session-expiry-auto-logout.md).
