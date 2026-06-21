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
- [x] **F1.3** [Codable data contract](superpowers/specs/01-foundations/data-contract-models.md) — Swift mirrors of `portal.ts`; admin types excluded · ✅ **done** ([plan](superpowers/plans/2026-06-20-codable-data-contract.md)) — full in-scope `portal.ts` contract mirrored + drift guard
- [x] **F1.4** [System & module discovery](superpowers/specs/01-foundations/system-module-discovery.md) — enabled modules (movie/tv) + `portalEnabled` · ✅ **done** ([plan](superpowers/plans/2026-06-20-system-module-discovery.md))
- [x] **F1.5** [Real-time polling engine](superpowers/specs/01-foundations/polling-engine.md) — shared interval poller; no websockets · ✅ **done** ([plan](superpowers/plans/2026-06-20-realtime-polling-engine.md)) — `@MainActor @Observable PollingEngine` in SlipStreamKit (per-stream interval, `scenePhase`-gated hard-stop, 401-suspend + `onUnauthorized`, enable-gated streams), wired into the app + a demo heartbeat stream
- [x] **F1.6** [App shell & navigation](superpowers/specs/01-foundations/app-shell-navigation.md) — Home/Search/Library/Settings chrome, adaptive · ✅ **done** ([plan](superpowers/plans/2026-06-20-app-shell-navigation.md)) — adaptive `TabView` + `.sidebarAdaptable` shell (`Feature-Shell`), pure `AppTab`/`NavigationModel` in the kit, reserved downloads-strip slot; verified tab bar (iPhone) + sidebar (iPad)
- [x] **F1.7** [Design system & visual identity](superpowers/specs/01-foundations/design-system-image-loading.md) — force-dark theme, Inter, Nuke posters, adaptive grid, skeletons, brand, status palette · ✅ **done** ([plan](superpowers/plans/2026-06-20-design-system-image-loading.md))

### 02 — Authentication & Session — [epic](superpowers/specs/02-authentication/README.md)

- [x] **F2.1** [PIN sign-in](superpowers/specs/02-authentication/pin-sign-in.md) — username + 4-digit PIN, remembered username, OTP auto-submit · ✅ **done** (core in Plan 1; remembered-username + Switch User + OTP auto-submit completed in F2.1's pass)
- [x] **F2.2** [Session persistence & Keychain/Face-ID](superpowers/specs/02-authentication/session-persistence-keychain.md) — store/restore JWT, auth guard · ✅ **done in Plan 1**
- [x] **F2.3** [Sign out](superpowers/specs/02-authentication/sign-out.md) — clear session + cached personal data · ✅ **done in Plan 1** (core)
- [x] **F2.4** [Session-expiry / 401 auto-logout](superpowers/specs/02-authentication/session-expiry-auto-logout.md) — recover from expired/rejected token · ✅ **done** ([plan](superpowers/plans/2026-06-20-session-expiry-auto-logout.md)) — central `SessionExpiry` funnels every token-bearing 401 (poll + non-poll) → pause poller + sign out; silent return to PIN
- [x] **F2.5** [Invitation signup](superpowers/specs/02-authentication/invitation-signup.md) — redeem invite, set PIN (iOS v1; manual link paste on free tier) · ✅ **done** ([plan](superpowers/plans/2026-06-20-invitation-signup.md)) — paste-link entry parses origin+token, 4-state flow (`InvitationSignupStore`), auto-sign-in via shared `AuthStore.establishSession`; verified end-to-end on-device against the live `--dev-mode` server
- [x] **F2.6** [Portal-disabled gate](superpowers/specs/02-authentication/portal-disabled-gate.md) — blocked state when the portal is off · ✅ **done** ([plan](superpowers/plans/2026-06-20-portal-disabled-gate.md)) — `AuthGateView` short-circuits to a `PortalDisabledView` when `!portalEnabled`, gating pre-auth + shell; `/status` refreshed on launch+foreground; no false lockout (optimistic default)

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
- **F1.3 (Codable data contract)** — **✅ complete** (2026-06-20): [`docs/superpowers/plans/2026-06-20-codable-data-contract.md`](superpowers/plans/2026-06-20-codable-data-contract.md). Mirrored the remaining `portal.ts` types into `SlipStreamKit` (enums, `JSONValue`, requests, search/availability, notifications/downloads) + a contract-drift guard; 7 TDD tasks, all headless via `swift test` (76/76 green).
- **F1.5 (real-time polling engine)** — **✅ complete** (2026-06-20): [`docs/superpowers/plans/2026-06-20-realtime-polling-engine.md`](superpowers/plans/2026-06-20-realtime-polling-engine.md). A shared `@MainActor @Observable PollingEngine` in `SlipStreamKit` (per-stream interval, `scenePhase`-gated hard-stop, 401-suspend + `onUnauthorized`, enable-gated streams); 3 TDD tasks (engine core, 401-suspend, app integration) + a demo heartbeat stream proving the lifecycle on-device. Kit logic headless via `swift test` (81/81 green). Resolves cadence (#5, per-stream configurable) and the spec's background-behavior question (hard-stop). Recovery UX (resume after 401) is wired minimally here (`resume()` on fresh sign-in); full re-prompt UX is F2.4. _Note: implementation also restored F1.4's system-discovery wiring, which the plan's verbatim file-replace had inadvertently dropped._
- **F1.6 (app shell & navigation)** — **✅ complete** (2026-06-20): [`docs/superpowers/plans/2026-06-20-app-shell-navigation.md`](superpowers/plans/2026-06-20-app-shell-navigation.md). One adaptive `TabView` + `.tabViewStyle(.sidebarAdaptable)` (`Feature-Shell`, iOS-only) renders a tab bar on iPhone (compact) and a sidebar on iPad/Mac (regular) — no platform branch; pure `AppTab`/`NavigationModel` live in `SlipStreamKit` (headless `swift test`, 86/86 green). Four thin placeholder tabs (Home/Search/Library/Settings) each in their own `NavigationStack`, Settings hosts Sign Out, plus a reserved downloads-strip `safeAreaInset` slot (F5.1 fills it). Verified on-device: iPhone tab bar + iPad sidebar, full sign-in→shell→sign-out loop. _Two fixes beyond the plan: (1) the reserved strip uses a zero-height `Color.clear`, not `EmptyView` — an `EmptyView` in `safeAreaInset` collapses the tab's content to the bottom; (2) re-attached F1.4's `system.refresh()` on the signed-in path (the plan's verbatim file-replace would have dropped it with `SignedInPlaceholderView` — the same hazard noted on F1.5). Both surgical, preserving F1.4/F1.5 wiring; the F1.4 drop was caught by `/code-review`._
- **F1.7 (design system & visual identity)** — **✅ complete** (2026-06-20): [`docs/superpowers/plans/2026-06-20-design-system-image-loading.md`](superpowers/plans/2026-06-20-design-system-image-loading.md). New iOS-only `DesignSystem` package (depends on `SlipStreamKit` + **Nuke 12.9.0** — the project's first third-party dep) carrying the full force-dark identity: `DesignTheme` tokens (semantic + movie/tv brand + media gradient), bundled **Inter Variable** font ramp, Nuke-backed `PosterImage` (2:3, pulse/shimmer, `ModuleType` fallback), adaptive `PosterGrid` + `PosterSizeSlider`, skeletons, empty/error states, brand logo/wordmark, and the 8-case `RequestStatus` palette/`StatusBadge`. Pure sizing/constants (`PosterGridMetrics`, `PosterSizePreference`, `RadiusScale`/`TypeScale`) live in `SlipStreamKit` (headless `swift test`, 98/98 green). App integration via **anchored edits only** (`DesignTheme.bootstrap()`, shared `PosterSizePreference`, `.preferredColorScheme(.dark)`, reactive poster-cache clear on sign-out) — F1.4/F1.5/F1.6 wiring preserved. DEBUG gallery (floating button → sheet) verified on **iPhone 17** (all 8 sections). _Notes: (1) `PosterGridMetrics.spacing` re-pinned to **16** (`gap-4`) per current web `MediaGrid`/library source — the plan's pre-survey 12 was stale; search skeleton keeps `gap-3`/12 explicitly. (2) pbxproj link required **6** entries (PBXBuildFile + Frameworks build phase), not the plan's 4, or the product resolves but doesn't link. (3) iPad gallery couldn't be screenshot-verified due to an XcodeBuildMCP multi-boot input bug + form-sheet scroll limitation (tooling, not app — see memory `xcodebuildmcp-ipad-input-gotchas`); iPad adaptivity is verified-by-construction + the iPhone grid._
- **F2.1 (PIN sign-in — completion)** — **✅ complete** (2026-06-21): finished the spec on top of Plan 1's core sign-in (no separate plan file — folded into Plan 1's spec). Added `LastUsernameStore` (UserDefaults-backed, mirroring `ServerConfigStore`) so `AuthStore` remembers the last **successfully** signed-in username (persisted on success only, never on a failed/invalid attempt) and exposes it as `lastUsername`; `SignInView` collapses a remembered username into a chip with **Switch User**, and a new 4-slot masked `PINEntryField` (single hidden number-pad field behind non-hit-testing dot slots + active-slot highlight) **auto-submits** the moment the PIN completes with a username present. Auto-submit is **focus-gated** (only fires while the PIN field is focused), so the DEBUG dev-credential pre-fill still requires a manual tap and never auto-logs-in; on failure the PIN clears and the username stays. Kit logic via TDD/headless `swift test` (105/105 green: `LastUsernameStoreTests` + `AuthStoreTests` remember/forget cases); full loop (sign-in → remembered chip after sign-out → Switch User → number-pad auto-submit) verified on **iPhone 17** against the live `--dev-mode` server.
- **F2.4 (session-expiry / 401 auto-logout)** — **✅ complete** (2026-06-20): [`docs/superpowers/plans/2026-06-20-session-expiry-auto-logout.md`](superpowers/plans/2026-06-20-session-expiry-auto-logout.md). A wiring feature on top of the F1.2/F1.5 seams: a tiny `@MainActor SessionExpiry` mediator (`weak auth` + `weak poller`) whose idempotent `handleUnauthorized()` pauses the poller then signs out, **gated on `state == .signedIn`** so a late/duplicate 401 can't strand the poller suspended on the sign-in screen. The app composes it once and funnels **both** paths through it — every `PortalAPIClient.onUnauthorized` (the unwired F1.2 hook, now live for token-bearing non-poll calls) and `PollingEngine.onUnauthorized` (poll 401s). `AuthStore.signOut()` made idempotent so a single expired token hitting both paths reacts once. Resolves the spec's open questions: **silent return to PIN** (no messaging, matches web) and **one path for both expired/revoked** (a portal client can't tell them apart). Kit logic via TDD/headless `swift test` (112/112 green: `SessionExpiryTests` + `AuthStore` signOut-idempotency cases); normal sign-in → shell → sign-out loop re-verified on **iPhone 17** against the live `--dev-mode` server (a live 401 is impractical with a 30-day JWT — the unit tests are the gate, per F1.5's precedent). Construction note: `system` moved from a property initializer into `init()` so its client factory can share the hook; two-phase weak-ref wiring resolves the `auth`↔`poller` cycle.
- **F2.5 (invitation signup)** — **✅ complete** (2026-06-20): [`docs/superpowers/plans/2026-06-20-invitation-signup.md`](superpowers/plans/2026-06-20-invitation-signup.md). Mirrors the web `signup.tsx` four-state route. **Networking:** two unauthenticated `AuthAPI` calls — `validateInvitation(token:)` and `signup(_:)` — plus query-string support on `PortalAPIClient` (the base64url token rides as a percent-handled `?token=` item, not baked into the path). **`InviteLinkParser`** (pure) extracts origin+token from a pasted `https://host/…/signup?token=…` link (free-tier entry; universal links stay paid-tier) or accepts a bare base64url token against an already-configured server. **`InvitationSignupStore`** (`@MainActor @Observable`) owns the phase machine — `awaitingToken / validating / invalid(reason) / ready(username) / creatingAccount` — mapping 404→notFound · 410→expired · 409→used · other→badToken · transport→network(retry), and commits the session through a new shared **`AuthStore.establishSession`** (the same finalize `signIn` uses — single session authority). **`InvitationSignupView`** (Feature-Auth) renders the phases, reuses `PINEntryField` (focus-gated auto-submit at 4 digits), reached via a "Have an invitation? Sign up" `.sheet` from `SignInView`; `expiresAt` not shown (matches web); `resendInvitation` left out (no web consumer). Kit logic via TDD/headless `swift test` (138/138 green: client query + both calls, `InviteLinkParserTests`, `establishSession`, full `InvitationSignupStoreTests` incl. valid:false + unknown-status paths). **Verified end-to-end on iPhone 17** against the live `--dev-mode` server with a real admin-minted invite: paste link → live validate → "Welcome, f25tester!" → PIN → live signup → app shell; server-confirmed the invite flipped to `409 used` and the new user logs in with the chosen PIN. Two small lint-driven adjustments (test-scoped `large_tuple`/`function_parameter_count` thresholds, never inline-disable) and a parser hardening to the base64url charset.
- **F2.6 (portal-disabled server gate)** — **✅ complete** (2026-06-20): [`docs/superpowers/plans/2026-06-20-portal-disabled-gate.md`](superpowers/plans/2026-06-20-portal-disabled-gate.md). A pure wiring feature on the F1.4 `SystemStore` + `AuthGateView` seams — no new model/networking code. New `PortalDisabledView` (in `Feature-Auth`, reusing `DesignSystem.EmptyStateView`; web copy verbatim — "Requests Portal Disabled" + `nosign`) is rendered by `AuthGateView` as its **first** branch when `!system.portalEnabled`, so a server `portalEnabled == false` replaces **both** the pre-auth sign-in screen and the signed-in shell from one decision point (the gate beats the restored-session shell). `RootView` folds a `/status` refresh into its existing `scenePhase` handler so discovery runs on **launch + foreground** (gate works pre-auth, reacts to an admin toggle on return) while keeping the signed-in `.task` refresh for fresh-sign-in module discovery (F1.4). `SystemStore`'s optimistic `portalEnabled = true` default means a cold launch never flashes "disabled" and a network blip / unreachable server never trips the gate — only an explicit server `false` does (mirrors web's `?? true`). Reactivity deliberately diverges from web's 30s poll: launch+foreground only, no pre-auth polling. Decision covered headless by the existing `SystemStoreTests.portalDisabledPropagates` (kit `swift test` 112/112 green); the full **enabled → disabled → recovered** cycle verified live on **iPhone 17** end-to-end against the dev server by toggling the server's `requests_portal_enabled` setting (no app-side scaffolding). Required only a one-line `Feature-Auth → DesignSystem` package edge (acyclic; no xcodeproj edit — `DesignSystem` is already linked into the app). **Known v1 limitation** (from `/code-review`): on a brand-new install before the first sign-in, `SystemStore.refresh()` no-ops (no persisted `serverConfig.baseURL` yet — the URL is stored only on first successful sign-in), so the gate can't show pre-first-signin; the disabled state is still enforced server-side (login is behind the `PortalEnabled()` middleware) and the gate applies from the first sign-in onward. Documented in the spec with a possible follow-up (probe `/status` for the typed URL on the sign-in screen).

## Development & Tooling

- ✅ **Live-testing enablers** — Debug-only local dev-server support: ATS `NSAllowsLocalNetworking` exception, sign-in dev-server picker, `SLIPSTREAM_BASE_URL` / `SLIPSTREAM_DEV_USERNAME` / `SLIPSTREAM_DEV_PIN` launch overrides, dev-credential pre-fill. Release unchanged. [`docs/superpowers/plans/2026-06-20-live-testing-enablers.md`](superpowers/plans/2026-06-20-live-testing-enablers.md)

## Scope decisions — resolved 2026-06-19

1. ✅ **Portal token authorizes `/api/v1/metadata/*`** — yes; the `/metadata` group is mounted under `AnyAuth()` (accepts the portal audience), `internal/api/routes.go:223-225`. **F3.3 stays v1.** (Caveat: needs a configured TMDB provider, else `503` — degrade gracefully.)
2. ✅ **`/api/v1/status` is public** — no token required (`internal/api/routes.go:107-108`); returns `enabledModules` + `portalEnabled`. **F1.4 & F2.6 unblocked**; the disabled-gate works pre-auth.
3. ✅ **In-app inbox cut from v1** — F6.1/F6.2 deferred (revisit with push); status rides on the request list. **Delivery channels F6.3/F6.4 stay v1.**
4. ✅ **Invitation signup is an iOS feature** — F2.5 stays v1; the free tier redeems via manual token entry (universal links need the paid-tier Associated Domains entitlement).

### Still open
5. ✅ **Polling cadence** — *resolved by F1.5:* not an engine decision. `PollStream.interval` is per-stream and configurable, so each feature picks its own cadence (F4.2 requests at 5s, F5.1 downloads at 3s) without an engine change; the demo stream uses 3s. Background behavior is a hard-stop (only `.active` polls).
6. **Notification "Test"** — the portal API has `POST /notifications/{id}/test` (saved-channel test, portal-scoped); the web's *in-form unsaved* test wrongly hits an admin endpoint. iOS should test saved channels via the portal endpoint and avoid the admin path — confirm there's no portal "test-unsaved" endpoint before designing F6.4.

## Source & provenance

- Contract source of truth: `~/Git/SlipStream/web/src/types/portal.ts` + `web/src/api/portal/*` (no OpenAPI spec — hand-mirror).
- Setup & decisions: [`docs/slipstream-ios-setup.md`](slipstream-ios-setup.md).
