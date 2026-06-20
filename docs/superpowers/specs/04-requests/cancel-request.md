---
epic: 04-requests
status: unrefined
type: feature
v1: true
plan: "Plan 3"
---

# Cancel a pending request

**Intent:** Let the owner of a request back out of it before it's approved, with a confirmation guard so it isn't done by accident.

## Summary
`DELETE /api/v1/requests/{id}` cancels a request. The action is owner-only and (per the web UI) only offered for pending requests, behind a confirmation prompt. The list/detail update on success.

## In scope
- A cancel action on the user's own pending requests.
- Confirmation prompt before cancelling.
- Update the list/detail after cancellation.

## Source of truth (web portal)
- `web/src/api/portal/requests.ts` `cancel`.
- `DELETE /api/v1/requests/{id}` → 204 / no body.

## iOS notes
- Native confirmation dialog; gate the action on `isOwner` + `pending`.

## Open questions
- [ ] Can non-pending requests ever be cancelled via a different path? (UI says no — confirm the server contract for portal tokens.)

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [request list](request-list.md), [request detail](request-detail.md).
