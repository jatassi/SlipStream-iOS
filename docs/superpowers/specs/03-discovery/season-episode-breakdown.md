---
epic: 03-discovery
status: unrefined
type: feature
v1: true
plan: "Plan 3"
---

# Series season & episode breakdown

**Intent:** For a series, show per-season availability and per-episode detail so the user understands exactly what's already there and what's missing before requesting.

## Summary
An expandable accordion of seasons, each with a computed status badge and per-episode rows. It both informs the user and feeds the season-picker that drives [create request](../04-requests/create-request.md) for missing seasons.

## In scope
- Seasons accordion; per-season status badge: **Available / Requested / Partial(aired-with-files / total) / Missing**.
- Per-episode rows (title, air date, `hasFile`, aired/monitored); future-air handling.
- Feed the season-selection request flow (incl. already-available / already-requested rows with inline Watch).

## Source of truth (web portal)
- `web/src/components/search/seasons-list.tsx` (`SeasonItem`, `SeasonStatusBadge`).
- `web/src/hooks/portal/use-portal-search.ts` `useSeriesSeasons` → `web/src/api/portal/search.ts` `getSeriesSeasons`.
- `GET /api/v1/requests/search/series/seasons?tmdbId=<>&tvdbId=<>` → `EnrichedSeason[]` (each with `EnrichedEpisode[]`).

## iOS notes
- SwiftUI `DisclosureGroup`/accordion; episode rows from `EnrichedEpisode`.
- Two availability sources can disagree (`AvailabilityInfo.seasonAvailability` vs `EnrichedSeason`) — pick an authority.

## Open questions
- [ ] Which source is authoritative for "available" when both `seasonAvailability` and `EnrichedSeason` are present?
- [ ] Show a badge for monitored-but-not-yet-downloaded seasons, or only fully available ones?

## Dependencies
- [Codable data contract](../01-foundations/data-contract-models.md), [media detail](media-detail-screen.md), [create request](../04-requests/create-request.md).
