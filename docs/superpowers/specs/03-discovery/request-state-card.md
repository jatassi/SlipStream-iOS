---
epic: 03-discovery
status: unrefined
type: feature
v1: true
plan: "own plan"
---

# Per-card request state machine

**Intent:** Make each poster/result card show the right state and action so the user always knows whether a title is in the library, available, already requested, or theirs to request.

## Summary
Every media card computes a state from the title's availability plus the user's own requests/downloads, and renders the matching action. This is core portal UX logic shared by both library and search grids — easy to under-build as a plain "Request" button.

## In scope (card states)
- **In Library**, **Available**, **Searching** (shimmer), **Approved**, **Requested** (the current user's own request), **View Request** (another user's existing request → deep-link to its detail), and **partial-request-allowed** (series with missing seasons).
- An **inline download-progress bar** replacing the button while the title is downloading.
- Own-vs-other-user distinction (uses the current user id).

## Source of truth (web portal)
- `web/src/components/search/card-action-button.tsx` (`ExistingRequestButton`), `use-external-media-card.ts`, `external-media-card.tsx`, `download-progress-bar.tsx`.
- Consumed by `search-media-grids.tsx` (search + partial library series).
- State derives from `AvailabilityInfo` (`inLibrary`, `canRequest`, `existingRequestId/UserId/Status/IsWatching`).

## iOS notes
- A reusable card view-model that resolves state from availability + requests + downloads; current user id from the auth store.
- The inline progress bar reuses the shared downloads data — see [request↔download matching](../05-downloads/download-request-matching.md).

## Open questions
- [ ] Confirm the precedence rules among "View Request" / "Request" / "In Library" / "Available" (logic lives in components outside the read set).
- [ ] How the "Searching" shimmer maps to a SwiftUI treatment.

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [create request](../04-requests/create-request.md), [watch request](../04-requests/watch-request.md), [per-request download progress](../05-downloads/request-download-progress.md).
