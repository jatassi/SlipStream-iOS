---
epic: 08-deferred
status: unrefined
type: feature
v1: false
plan: "Deferred (needs server change)"
---

# Quota display

**Intent:** Show the user their per-module request quota (used vs. limit, current period) so they know how much they can still request.

> ⛔ **Deferred for v1.** There is **no portal-scoped quota endpoint** — quota reads are admin-only — and an over-quota request still returns `201` rather than erroring. A quota meter isn't buildable against the current API without a small **server addition**. The `QuotaStatus` types exist in the contract but aren't portal-reachable.

## Summary
When un-deferred (after a server adds a portal quota endpoint), show a per-module quota meter and surface over-quota state at request time.

## In scope (when un-deferred)
- Per-module quota meter (`quotaUsed` / `quotaLimit` / `periodStart`).
- Over-quota messaging on [create request](../04-requests/create-request.md) (today create still returns 201).

## Source of truth (web portal)
- `web/src/types/portal.ts` `QuotaStatus`, `ModuleQuotaStatus`, `PortalUserWithQuota` (types only — no portal endpoint).
- Setup doc §9 (cut from v1).

## iOS notes
- Blocked on a portal-scoped quota endpoint server-side; excluded from the [data contract](../01-foundations/data-contract-models.md) until then.

## Open questions
- [ ] Will the server expose a portal quota endpoint?
- [ ] How should over-quota surface at create time (currently a silent 201)?

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [create request](../04-requests/create-request.md).
