# SlipStream iOS — Feature Specs

Unrefined feature backlog for the **SlipStream iOS portal-companion app**, combed from the SlipStream server's **portal web frontend** (`~/Git/SlipStream/web/src` — `routes/requests/**`, `components/portal/**`, `hooks/portal/**`, `api/portal/**`, `types/portal.ts`).

These are **Epics → Features**. Each feature here is an *unrefined stub*: enough for a refiner to know the intent and where to look, deliberately light on implementation detail so it doesn't go stale as the build progresses. Refinement breaks each stub into Tasks (not created here).

See [`docs/TRACKER.md`](../../TRACKER.md) for the full checkbox enumeration, v1-vs-deferred status, and per-feature plan status. **Plans map 1:1 to specs** — each feature here becomes one plan in `docs/superpowers/plans/` when refined; **Plan 1 (foundation)** is the one exception (it bundles the foundation + auth core and is in progress).

## Epics

| # | Epic | What it covers |
| --- | --- | --- |
| 01 | [Foundations & App Shell](01-foundations/README.md) | Networking client, data contract, module discovery, polling engine, navigation shell, design system / image loading |
| 02 | [Authentication & Session](02-authentication/README.md) | PIN sign-in, Keychain/Face-ID session, sign-out, expiry handling, invitation signup, portal-disabled gate |
| 03 | [Discovery: Library & Search](03-discovery/README.md) | Library poster grid, title search, rich media-detail screen, per-card request state, season/episode breakdown |
| 04 | [Media Requests](04-requests/README.md) | Create request (movie + season picker), request list, request detail, cancel, watch/follow |
| 05 | [Downloads & Progress](05-downloads/README.md) | Global downloads strip, per-request progress, request↔download matching |
| 06 | [Notifications](06-notifications/README.md) | In-app inbox (bell + list + read-state), notification delivery channels |
| 07 | [Account & Settings](07-settings/README.md) | Settings shell, change PIN, edit profile |
| 08 | [Deferred (post-v1 / paid-tier)](08-deferred/README.md) | Passkeys, push notifications, quota display |

## Scope

- **Audience:** the owner + a few trusted family members (the broader, less-trusted audience stays on the web portal).
- **Auth:** portal credential only — username + 4-digit PIN → 30-day JWT (no refresh). A **portal token cannot reach admin endpoints.**
- **Out of scope entirely:** the admin request queue (`routes/requests-admin/**` — approve/deny, invitations management, user management, quota config). A portal-token client can't call those endpoints; that surface stays on the web portal.
- **Deferred (Epic 08):** passkeys (need the Associated Domains entitlement — paid Apple Developer Program), push/APNs (paid), quota display (no portal-scoped endpoint exists today).

## Stub conventions

Each stub carries YAML frontmatter (`epic`, `status`, `type`, `v1`, `plan`) and these sections: **Intent · Summary · In scope · Source of truth · iOS notes · Open questions · Dependencies**. The *Source of truth* section points at the canonical web-portal files/endpoints/types so refiners verify against live server code rather than this doc. Web paths are relative to `~/Git/SlipStream/web/`.
