# SlipStream iOS — Feature Tracker

A backlog of the features the iOS **portal-companion** app must implement, combed from the SlipStream server's **portal web frontend** (`~/Git/SlipStream/web/src` — `routes/requests/**`, `components/portal/**`, `hooks/portal/**`, `api/portal/**`, `types/portal.ts`).

Each item is an **unrefined Feature** (Epic → Feature). Full stubs live in [`docs/superpowers/specs/`](superpowers/specs/README.md); refinement breaks each into Tasks. This file is the at-a-glance checklist and plan status.

- **Audience:** the owner + a few trusted family members (everyone else stays on the web portal).
- **Auth:** username + 4-digit PIN → 30-day JWT (no refresh). **A portal token cannot reach admin endpoints.**
- **Target:** iOS/iPadOS 26, Swift 6, SwiftUI; iPhone + iPad + Mac (Designed-for-iPad). Free Apple Personal Team.

## Legend

- `[ ]` not yet built · `[x]` done
- **One plan per spec.** Each feature below maps 1:1 to its own plan in [`docs/superpowers/plans/`](superpowers/plans/), written when that feature is refined. The **one exception is Plan 1 (foundation)** — it bundles the foundation + auth core and is **✅ complete** (merged `d268544`). Per-feature delivery: **· ✅ done in Plan 1** = delivered; **· ◑ Plan 1: …** = a foundation slice landed, the rest is pending in this feature's own plan.
- ✂️ = cut from v1 (revisit later) · ⛔ = deferred (paid tier / server change), see Epic 08.

---

## v1 backlog

### 01 — Foundations & App Shell — [epic](superpowers/specs/01-foundations/README.md)

- [x] **F1.1** [Server connection onboarding](superpowers/specs/01-foundations/server-connection-onboarding.md) — capture & persist the HTTPS server origin (native-only) · ✅ **done in Plan 1**
- [x] **F1.2** [Portal API client](superpowers/specs/01-foundations/portal-api-client.md) — typed client, base path, Bearer JWT, error model, 204/empty handling, multi-base (portal/metadata/status), central 401 hook · ✅ **infra done** (per-resource methods grow per feature)
- [ ] ◑ **F1.3** [Codable data contract](superpowers/specs/01-foundations/data-contract-models.md) — Swift mirrors of `portal.ts`; admin types excluded · ◑ **Plan 1: auth-subset models done** · 📋 [plan](superpowers/plans/2026-06-20-codable-data-contract.md)
- [x] **F1.4** [System & module discovery](superpowers/specs/01-foundations/system-module-discovery.md) — enabled modules (movie/tv) + `portalEnabled` · ✅ **done** ([plan](superpowers/plans/2026-06-20-system-module-discovery.md))
- [ ] **F1.5** [Real-time polling engine](superpowers/specs/01-foundations/polling-engine.md) — shared interval poller; no websockets · 📋 [plan](superpowers/plans/2026-06-20-realtime-polling-engine.md)
- [ ] ◑ **F1.6** [App shell & navigation](superpowers/specs/01-foundations/app-shell-navigation.md) — Home/Search/Library/Settings chrome, adaptive · ◑ **Plan 1: gate skeleton done** · 📋 [plan](superpowers/plans/2026-06-20-app-shell-navigation.md)
- [ ] **F1.7** [Design system & image loading](superpowers/specs/01-foundations/design-system-image-loading.md) — Nuke posters, adaptive grid, skeletons · 📋 [plan](superpowers/plans/2026-06-20-design-system-image-loading.md)

### 02 — Authentication & Session — [epic](superpowers/specs/02-authentication/README.md)

- [ ] ◑ **F2.1** [PIN sign-in](superpowers/specs/02-authentication/pin-sign-in.md) — username + 4-digit PIN, remembered username, OTP auto-submit · ◑ **Plan 1: core sign-in done**
- [x] **F2.2** [Session persistence & Keychain/Face-ID](superpowers/specs/02-authentication/session-persistence-keychain.md) — store/restore JWT, auth guard · ✅ **done in Plan 1**
- [x] **F2.3** [Sign out](superpowers/specs/02-authentication/sign-out.md) — clear session + cached personal data · ✅ **done in Plan 1** (core)
- [ ] ◑ **F2.4** [Session-expiry / 401 auto-logout](superpowers/specs/02-authentication/session-expiry-auto-logout.md) — recover from expired/rejected token · ◑ **Plan 1: restore-path 401 done**
- [ ] **F2.5** [Invitation signup](superpowers/specs/02-authentication/invitation-signup.md) — redeem invite, set PIN (iOS v1; manual token entry on free tier)
- [ ] **F2.6** [Portal-disabled gate](superpowers/specs/02-authentication/portal-disabled-gate.md) — blocked state when the portal is off

### 03 — Discovery: Library & Search — [epic](superpowers/specs/03-discovery/README.md)

- [ ] **F3.1** [Library poster grid](superpowers/specs/03-discovery/library-poster-grid.md) — Movies/Series tabs of in-library titles
- [ ] **F3.2** [Title search](superpowers/specs/03-discovery/title-search.md) — movie & series search, In-Library vs Request grouping
- [ ] **F3.3** [Rich media-detail screen](superpowers/specs/03-discovery/media-detail-screen.md) — extended metadata, cast, ratings, trailer *(2nd base `/api/v1/metadata`; portal token OK)*
- [ ] **F3.4** [Per-card request state machine](superpowers/specs/03-discovery/request-state-card.md) — In Library/Available/Searching/Requested/View Request + inline progress
- [ ] **F3.5** [Season & episode breakdown](superpowers/specs/03-discovery/season-episode-breakdown.md) — per-season badges, per-episode rows

### 04 — Media Requests — [epic](superpowers/specs/04-requests/README.md)

- [ ] **F4.1** [Create request](superpowers/specs/04-requests/create-request.md) — one-tap movie; series season/monitor-future dialog
- [ ] **F4.2** [Request list (Mine/All)](superpowers/specs/04-requests/request-list.md) — scrollable history, 8-state status, live
- [ ] **F4.3** [Request detail](superpowers/specs/04-requests/request-detail.md) — status, metadata, approval/denial, live progress
- [ ] **F4.4** [Cancel a pending request](superpowers/specs/04-requests/cancel-request.md) — owner-only, with confirmation
- [ ] **F4.5** [Watch / unwatch a request](superpowers/specs/04-requests/watch-request.md) — follow the household's requests

### 05 — Downloads & Progress — [epic](superpowers/specs/05-downloads/README.md)

- [ ] **F5.1** [Global downloads strip](superpowers/specs/05-downloads/downloads-strip.md) — app-wide in-flight downloads
- [ ] **F5.2** [Per-request download progress](superpowers/specs/05-downloads/request-download-progress.md) — aggregated progress for one request
- [ ] **F5.3** [Request ↔ download matching](superpowers/specs/05-downloads/download-request-matching.md) — mediaId → normalized-title matching

### 06 — Notifications — [epic](superpowers/specs/06-notifications/README.md)

- [ ] ✂️ **F6.1** [Inbox bell & unread indicator](superpowers/specs/06-notifications/inbox-bell-badge.md) — header bell, unread badge · **cut from v1** (revisit w/ push)
- [ ] ✂️ **F6.2** [Inbox list & read-state](superpowers/specs/06-notifications/inbox-list-read-state.md) — recent notifications, mark-read, deep-link · **cut from v1** (revisit w/ push)
- [ ] **F6.3** [Manage delivery channels](superpowers/specs/06-notifications/delivery-channels-manage.md) — list, enable/disable, test, delete
- [ ] **F6.4** [Channel editor (schema-driven)](superpowers/specs/06-notifications/channel-editor-schema-form.md) — add/edit via server notifier schema

### 07 — Account & Settings — [epic](superpowers/specs/07-settings/README.md)

- [ ] **F7.1** [Settings shell & navigation](superpowers/specs/07-settings/settings-shell.md) — Security/Notifications tabs, logout
- [ ] **F7.2** [Change PIN](superpowers/specs/07-settings/change-pin.md) — 3-step verify → new → confirm
- [ ] **F7.3** [Edit profile (username)](superpowers/specs/07-settings/edit-profile.md) — optional; endpoint supports it, web doesn't wire it

---

## Deferred — post-v1 / paid-tier · ⛔ [epic](superpowers/specs/08-deferred/README.md)

- [ ] ⛔ **F8.1** [Passkey authentication & management](superpowers/specs/08-deferred/passkey-authentication.md) — WebAuthn login/register/manage · needs Associated Domains (paid)
- [ ] ⛔ **F8.2** [Push notifications](superpowers/specs/08-deferred/push-notifications.md) — APNs for request lifecycle · needs paid tier + server endpoint
- [ ] ⛔ **F8.3** [Quota display](superpowers/specs/08-deferred/quota-display.md) — per-module quota meter · needs a portal quota endpoint server-side

## Explicitly out of scope (not deferred)

- **Admin request queue** — approve/deny, batch actions, invitation management, user management, quota config (`web/src/routes/requests-admin/**`). A portal token can't call admin endpoints; this is the admin audience's surface and stays on the web portal. No stubs created.

---

## Plans

- **Convention: one plan per spec.** When a feature is refined, write a single plan for it under [`docs/superpowers/plans/`](superpowers/plans/) (named for the feature). There is no Plans 2–4 roadmap — each spec is its own plan.
- **Plan 1 (foundation)** is **✅ complete** — implemented and squash-merged to `main` in `d268544` (2026-06-20); `swift test` green (11/11). [`docs/superpowers/plans/2026-06-19-slipstream-ios-foundation.md`](superpowers/plans/2026-06-19-slipstream-ios-foundation.md). It delivered the features marked **· ✅ done / ◑ Plan 1** above; its internal roadmap section has been trimmed to match the one-plan-per-spec model.
- **F1.3 (Codable data contract)** — plan written 2026-06-20, not yet implemented: [`docs/superpowers/plans/2026-06-20-codable-data-contract.md`](superpowers/plans/2026-06-20-codable-data-contract.md). Mirrors the remaining `portal.ts` types into `SlipStreamKit` (enums, `JSONValue`, requests, search/availability, notifications/downloads) + a contract-drift guard; 7 TDD tasks, all headless via `swift test`.
- **F1.5 (real-time polling engine)** — plan written 2026-06-20, not yet implemented: [`docs/superpowers/plans/2026-06-20-realtime-polling-engine.md`](superpowers/plans/2026-06-20-realtime-polling-engine.md). A shared `@MainActor @Observable PollingEngine` in `SlipStreamKit` (per-stream interval, `scenePhase`-gated, 401-suspend, enable-gated streams); 3 TDD tasks (engine core, 401-suspend, app integration), kit logic headless via `swift test`.

## Scope decisions — resolved 2026-06-19

1. ✅ **Portal token authorizes `/api/v1/metadata/*`** — yes; the `/metadata` group is mounted under `AnyAuth()` (accepts the portal audience), `internal/api/routes.go:223-225`. **F3.3 stays v1.** (Caveat: needs a configured TMDB provider, else `503` — degrade gracefully.)
2. ✅ **`/api/v1/status` is public** — no token required (`internal/api/routes.go:107-108`); returns `enabledModules` + `portalEnabled`. **F1.4 & F2.6 unblocked**; the disabled-gate works pre-auth.
3. ✅ **In-app inbox cut from v1** — F6.1/F6.2 deferred (revisit with push); status rides on the request list. **Delivery channels F6.3/F6.4 stay v1.**
4. ✅ **Invitation signup is an iOS feature** — F2.5 stays v1; the free tier redeems via manual token entry (universal links need the paid-tier Associated Domains entitlement).

### Still open
5. **Polling cadence** — uniform ~3s, or match the web's 5s-requests / 3s-downloads split? — affects F1.5 and the request/download features.
6. **Notification "Test"** — the portal API has `POST /notifications/{id}/test` (saved-channel test, portal-scoped); the web's *in-form unsaved* test wrongly hits an admin endpoint. iOS should test saved channels via the portal endpoint and avoid the admin path — confirm there's no portal "test-unsaved" endpoint before designing F6.4.

## Source & provenance

- Contract source of truth: `~/Git/SlipStream/web/src/types/portal.ts` + `web/src/api/portal/*` (no OpenAPI spec — hand-mirror).
- Setup & decisions: [`docs/slipstream-ios-setup.md`](slipstream-ios-setup.md).
