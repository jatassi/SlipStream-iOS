# SlipStream iOS — Feature Tracker

A backlog of the features the iOS **portal-companion** app must implement, combed from the SlipStream server's **portal web frontend** (`~/Git/SlipStream/web/src` — `routes/requests/**`, `components/portal/**`, `hooks/portal/**`, `api/portal/**`, `types/portal.ts`).

Each item is an **unrefined Feature** (Epic → Feature). Full stubs live in [`docs/superpowers/specs/`](superpowers/specs/README.md); refinement breaks each into Tasks. This file is the at-a-glance checklist and roadmap mapping.

- **Audience:** the owner + a few trusted family members (everyone else stays on the web portal).
- **Auth:** username + 4-digit PIN → 30-day JWT (no refresh). **A portal token cannot reach admin endpoints.**
- **Target:** iOS/iPadOS 26, Swift 6, SwiftUI; iPhone + iPad + Mac (Designed-for-iPad). Free Apple Personal Team.

## Legend

- `[ ]` not yet built · `[x]` done
- **Plan N** = mapped to the existing roadmap doc in [`docs/superpowers/plans/`](superpowers/plans/) (Plan 1 foundation · Plan 2 library · Plan 3 search/requests · Plan 4 polling). **—** = not covered by the current 4 plans.
- ✂️ = cut from v1 (revisit later) · ⛔ = deferred (paid tier / server change), see Epic 08.

---

## v1 backlog

### 01 — Foundations & App Shell · Plans 1 & 4 — [epic](superpowers/specs/01-foundations/README.md)

- [ ] **F1.1** [Server connection onboarding](superpowers/specs/01-foundations/server-connection-onboarding.md) — capture & persist the HTTPS server origin (native-only) · Plan 1
- [ ] **F1.2** [Portal API client](superpowers/specs/01-foundations/portal-api-client.md) — typed client, base path, Bearer JWT, error model, 401 hook · Plan 1+
- [ ] **F1.3** [Codable data contract](superpowers/specs/01-foundations/data-contract-models.md) — Swift mirrors of `portal.ts`; admin types excluded · Plans 1–3
- [ ] **F1.4** [System & module discovery](superpowers/specs/01-foundations/system-module-discovery.md) — enabled modules (movie/tv) + `portalEnabled` · —
- [ ] **F1.5** [Real-time polling engine](superpowers/specs/01-foundations/polling-engine.md) — shared interval poller; no websockets · Plan 4
- [ ] **F1.6** [App shell & navigation](superpowers/specs/01-foundations/app-shell-navigation.md) — Home/Search/Library/Settings chrome, adaptive · Plan 2+
- [ ] **F1.7** [Design system & image loading](superpowers/specs/01-foundations/design-system-image-loading.md) — Nuke posters, adaptive grid, skeletons · Plan 2

### 02 — Authentication & Session · Plan 1 — [epic](superpowers/specs/02-authentication/README.md)

- [ ] **F2.1** [PIN sign-in](superpowers/specs/02-authentication/pin-sign-in.md) — username + 4-digit PIN, remembered username, OTP auto-submit · Plan 1
- [ ] **F2.2** [Session persistence & Keychain/Face-ID](superpowers/specs/02-authentication/session-persistence-keychain.md) — store/restore JWT, auth guard · Plan 1
- [ ] **F2.3** [Sign out](superpowers/specs/02-authentication/sign-out.md) — clear session + cached personal data · Plan 1
- [ ] **F2.4** [Session-expiry / 401 auto-logout](superpowers/specs/02-authentication/session-expiry-auto-logout.md) — recover from expired/rejected token · Plans 1 & 4
- [ ] **F2.5** [Invitation signup](superpowers/specs/02-authentication/invitation-signup.md) — redeem invite, set PIN (iOS v1; manual token entry on free tier) · —
- [ ] **F2.6** [Portal-disabled gate](superpowers/specs/02-authentication/portal-disabled-gate.md) — blocked state when the portal is off · —

### 03 — Discovery: Library & Search · Plans 2 & 3 — [epic](superpowers/specs/03-discovery/README.md)

- [ ] **F3.1** [Library poster grid](superpowers/specs/03-discovery/library-poster-grid.md) — Movies/Series tabs of in-library titles · Plan 2
- [ ] **F3.2** [Title search](superpowers/specs/03-discovery/title-search.md) — movie & series search, In-Library vs Request grouping · Plan 3
- [ ] **F3.3** [Rich media-detail screen](superpowers/specs/03-discovery/media-detail-screen.md) — extended metadata, cast, ratings, trailer *(2nd base `/api/v1/metadata`; portal token OK)* · —
- [ ] **F3.4** [Per-card request state machine](superpowers/specs/03-discovery/request-state-card.md) — In Library/Available/Searching/Requested/View Request + inline progress · Plan 3
- [ ] **F3.5** [Season & episode breakdown](superpowers/specs/03-discovery/season-episode-breakdown.md) — per-season badges, per-episode rows · Plan 3

### 04 — Media Requests · Plan 3 — [epic](superpowers/specs/04-requests/README.md)

- [ ] **F4.1** [Create request](superpowers/specs/04-requests/create-request.md) — one-tap movie; series season/monitor-future dialog · Plan 3
- [ ] **F4.2** [Request list (Mine/All)](superpowers/specs/04-requests/request-list.md) — scrollable history, 8-state status, live · Plan 3
- [ ] **F4.3** [Request detail](superpowers/specs/04-requests/request-detail.md) — status, metadata, approval/denial, live progress · Plan 3
- [ ] **F4.4** [Cancel a pending request](superpowers/specs/04-requests/cancel-request.md) — owner-only, with confirmation · Plan 3
- [ ] **F4.5** [Watch / unwatch a request](superpowers/specs/04-requests/watch-request.md) — follow the household's requests · Plan 3

### 05 — Downloads & Progress · Plan 4 — [epic](superpowers/specs/05-downloads/README.md)

- [ ] **F5.1** [Global downloads strip](superpowers/specs/05-downloads/downloads-strip.md) — app-wide in-flight downloads · Plan 4
- [ ] **F5.2** [Per-request download progress](superpowers/specs/05-downloads/request-download-progress.md) — aggregated progress for one request · Plan 4
- [ ] **F5.3** [Request ↔ download matching](superpowers/specs/05-downloads/download-request-matching.md) — mediaId → normalized-title matching · Plan 4

### 06 — Notifications — [epic](superpowers/specs/06-notifications/README.md)

- [ ] ✂️ **F6.1** [Inbox bell & unread indicator](superpowers/specs/06-notifications/inbox-bell-badge.md) — header bell, unread badge · **cut from v1** (revisit w/ push)
- [ ] ✂️ **F6.2** [Inbox list & read-state](superpowers/specs/06-notifications/inbox-list-read-state.md) — recent notifications, mark-read, deep-link · **cut from v1** (revisit w/ push)
- [ ] **F6.3** [Manage delivery channels](superpowers/specs/06-notifications/delivery-channels-manage.md) — list, enable/disable, test, delete · —
- [ ] **F6.4** [Channel editor (schema-driven)](superpowers/specs/06-notifications/channel-editor-schema-form.md) — add/edit via server notifier schema · —

### 07 — Account & Settings — [epic](superpowers/specs/07-settings/README.md)

- [ ] **F7.1** [Settings shell & navigation](superpowers/specs/07-settings/settings-shell.md) — Security/Notifications tabs, logout · —
- [ ] **F7.2** [Change PIN](superpowers/specs/07-settings/change-pin.md) — 3-step verify → new → confirm · —
- [ ] **F7.3** [Edit profile (username)](superpowers/specs/07-settings/edit-profile.md) — optional; endpoint supports it, web doesn't wire it · —

---

## Deferred — post-v1 / paid-tier · ⛔ [epic](superpowers/specs/08-deferred/README.md)

- [ ] ⛔ **F8.1** [Passkey authentication & management](superpowers/specs/08-deferred/passkey-authentication.md) — WebAuthn login/register/manage · needs Associated Domains (paid)
- [ ] ⛔ **F8.2** [Push notifications](superpowers/specs/08-deferred/push-notifications.md) — APNs for request lifecycle · needs paid tier + server endpoint
- [ ] ⛔ **F8.3** [Quota display](superpowers/specs/08-deferred/quota-display.md) — per-module quota meter · needs a portal quota endpoint server-side

## Explicitly out of scope (not deferred)

- **Admin request queue** — approve/deny, batch actions, invitation management, user management, quota config (`web/src/routes/requests-admin/**`). A portal token can't call admin endpoints; this is the admin audience's surface and stays on the web portal. No stubs created.

---

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
- Roadmap: [`docs/superpowers/plans/`](superpowers/plans/) (Plan 1 written; Plans 2–4 to follow).
- Setup & decisions: [`docs/slipstream-ios-setup.md`](slipstream-ios-setup.md).
