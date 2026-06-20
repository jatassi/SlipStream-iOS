---
epic: 01-foundations
status: complete
type: feature
v1: true
plan: "Plan 1 (auth subset) + Plan 2 (2026-06-20-codable-data-contract: remainder + drift guard)"
---

# Codable data contract (mirror of portal.ts)

> **Status (2026-06-20):** ✅ **Complete** — Plan 1 (`d268544`) delivered the auth-subset models (`PortalUser`, `UserModuleSetting`, `LoginRequest`/`LoginResponse`); Plan 2 (`2026-06-20-codable-data-contract`) mirrored the rest of the in-scope `portal.ts` contract — string-union enums, recursive `JSONValue`, signup/profile/invitation/PIN auth types, `Request`/`CreateRequestInput`/`RequestListFilters`, search & availability (`PortalMovieSearchResult`/`PortalSeriesSearchResult`/`AvailabilityInfo`/`SlotInfo`/`SeasonAvailabilityInfo`/`EnrichedSeason`/`EnrichedEpisode`), `UserNotification`/`CreateUserNotificationInput`, and `PortalDownload` — plus a self-contained contract-drift guard over a vendored `portal.ts` snapshot. Admin/deferred/cut types remain deliberately excluded (enforced by the drift guard).

**Intent:** Define the Swift `Codable` types that mirror the server's hand-written `portal.ts` so every feature decodes the same canonical shapes — there is no OpenAPI spec to generate from.

## Summary
Hand-mirror the portal contract verbatim (camelCase) into `SlipStreamKit`. This is the single source the auth, requests, search, library, inbox, and notification features all decode against. Admin-only input types are deliberately excluded — a portal token can't call the endpoints they serve.

## In scope
- `PortalUser` / `UserModuleSetting`; auth (`LoginRequest/Response`, `SignupRequest/Response`, `UpdateProfileRequest`, `ValidateInvitationResponse`, `VerifyPinResponse`).
- `Request` (+ `RequestStatus` 8-state enum, `PortalMediaType`), `CreateRequestInput`, `RequestListFilters`.
- Search/availability: `PortalMovieSearchResult`, `PortalSeriesSearchResult`, `AvailabilityInfo`, `SlotInfo`, `SeasonAvailabilityInfo`, `EnrichedSeason`, `EnrichedEpisode`.
- `PortalDownload`; `UserNotification` / `CreateUserNotificationInput`; inbox list/count types.
- Timestamps modeled as `String` in v1 (no date parsing).

## Excluded (admin / deferred)
- `ApproveRequestInput`, `DenyRequestInput`, `BatchApprove/DenyInput`, `AdminUpdateUserInput`, `CreateInvitationRequest`, `Invitation*`, `RequestSettings`, `QuotaStatus`/`ModuleQuotaStatus` (quota is [deferred](../08-deferred/quota-display.md)).

## Source of truth (web portal)
- `web/src/types/portal.ts` (≈326 lines — canonical).
- Already mirrored (auth subset): **Plan 1** `PortalUser`, `LoginRequest/Response`.

## iOS notes
- Mirror field names verbatim; add a CI drift check that diffs a vendored `portal.ts` against the server's.
- Choose one timestamp decoding strategy once dates are parsed.

## Open questions
- [ ] Exact server timestamp formats (fractional seconds?) to pick a decoding strategy.
- [ ] Which optional fields are genuinely nullable vs always present from the Go server.

## Dependencies
- None (foundational; consumed everywhere).
