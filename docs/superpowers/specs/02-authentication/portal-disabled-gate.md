---
epic: 02-authentication
status: done
type: feature
v1: true
plan: "2026-06-20-portal-disabled-gate"
---

# Portal-disabled server gate

> **Status (2026-06-20):** ✅ **Done** — [plan](../../plans/2026-06-20-portal-disabled-gate.md). A pure wiring feature on the existing F1.4 `SystemStore` + `AuthGateView` seams: a new `PortalDisabledView` (reuses `DesignSystem.EmptyStateView`, web copy verbatim), `AuthGateView` short-circuits to it as its **first** branch when `!system.portalEnabled` (gating pre-auth sign-in *and* the signed-in shell), and `RootView` refreshes `/status` on **launch + foreground** so the gate works before auth. Optimistic `portalEnabled = true` default means no false lockout on a network blip. Decision covered by `SystemStoreTests.portalDisabledPropagates`; full enabled→disabled→recovered cycle verified live on iPhone 17 against the dev server.

**Intent:** When the server administrator has turned the external requests portal off, show a clear "disabled" message instead of any auth or app UI.

## Summary
The server exposes a `portalEnabled` flag (on the system/status endpoint). When it's `false`, the whole portal — including the pre-auth login screen — is replaced by a disabled state. This must work *before* the user is authenticated, so the status endpoint has to be callable without a token.

## In scope
- Read `portalEnabled`; when `false`, render a disabled view in place of auth/app UI.
- Make the gate work on the pre-auth login/signup screens.

## Source of truth (web portal)
- Auth area "Portal-Disabled Server Gate"; App-shell "Portal Auth Guard & Disabled-Portal Gate".
- `GET /api/v1/status` exposes `portalEnabled` (read via `useStatus()/usePortalEnabled()`); web shows `PortalDisabledView`.
- Web copy (mirrored verbatim): title **"Requests Portal Disabled"**, body **"The external requests portal is currently disabled. Please contact your server administrator."**, lucide `Ban` icon. The web renders this view in three places (`portal-auth-guard.tsx`, `login.tsx`, `signup.tsx`); iOS centralizes it into one gate.
- `usePortalEnabled()` returns `data?.portalEnabled ?? true` — i.e. **defaults to enabled** while status is loading or unavailable; status auto-refetches every 30s.

## iOS notes
- Confirmed: `portalEnabled` comes from the **public** `GET /api/v1/status` (`internal/api/routes.go:107-108`), so the gate works on the pre-auth login/signup screens with no token — ties into [system & module discovery](../01-foundations/system-module-discovery.md).

## Approach (refined 2026-06-20)

A small wiring feature on top of the existing `SystemStore` (F1.4) and `AuthGateView` seams. No new model or networking code — `SystemStore.refresh()` already loads `/status` and exposes `portalEnabled` with an **optimistic `true` default** before the first successful load.

- **`PortalDisabledView`** — new view in `Feature-Auth` (same level as `AuthGateView`). A thin wrapper over the existing `DesignSystem.EmptyStateView` carrying the web copy above (SF Symbol `nosign`). Reuse, not a new layout; ships with a `#Preview`.
- **Gate placement — `AuthGateView`.** Add `@Environment(SystemStore.self)` and a new **first** branch: `if !system.portalEnabled → PortalDisabledView`, evaluated *before* the restore spinner and the signedOut/signedIn switch. Because `AuthGateView` wraps both the pre-auth sign-in screen and the signed-in shell, this single decision point gates everything (and will naturally cover F2.5's future signup entry, which sits inside the signed-out flow).
- **Status fetch lifecycle — launch + foreground.** Today `system.refresh()` runs only on the signed-in branch. Fold launch+foreground into `RootView`'s existing `.onChange(of: scenePhase, initial: true)` handler (already fires once on launch via `initial: true`, then on every foreground): when the phase resolves to `.active`, also kick `Task { await system.refresh() }`. **Keep** the signed-in `.task { await system.refresh() }` so fresh-sign-in module discovery (F1.4/F3.x) is unaffected — the redundant fetch immediately after sign-in is idempotent and harmless, and preserving that wiring avoids the F1.4-drop hazard noted in prior plans.
- **Error handling — no false lockout.** `refresh()` already swallows failures and keeps the last status, falling back to the optimistic `portalEnabled = true` before any successful load. So a cold launch shows normal UI (no flash of "disabled"), and a network blip / unreachable server never trips the gate — it fires only on an explicit `false` from the server. Matches the web's `?? true`.

### Reactivity decision
- **Launch + foreground** (not continuous polling). The portal toggle is an admin action between sessions, not something to poll for live. A mid-session toggle takes effect after a background→foreground round-trip. No pre-auth polling and no new `PollingEngine` wiring. (Web polls `/status` every 30s; iOS deliberately diverges here for v1 simplicity.)

## Out of scope
- No retry button on the disabled view (web has none; foreground refresh covers recovery).
- No distinct messaging or per-reason variants — one static disabled state.
- No change to the DEBUG gallery overlay (it lives in `RootView` outside the gate, DEBUG-only).

## Known limitation (v1) — fresh install before first sign-in
Unlike the web app (served from the server origin, so it always knows where to call), the native app must be told the server URL. `SystemStore.refresh()` no-ops while `serverConfig.baseURL` is `nil`, and that URL is persisted only on the **first successful sign-in** (`AuthStore.signIn`). Consequences on a brand-new install whose portal is disabled, **before any successful sign-in**:
- `/status` is never fetched (no URL known), so `portalEnabled` stays at the optimistic `true` default → the **sign-in screen shows instead of the gate**.
- The disabled state is still enforced **server-side**: the `/api/v1/requests/auth` group (login/signup/profile) is behind the server's `PortalEnabled()` middleware (`internal/api/routes.go:354`), so a login attempt is rejected — the user sees a login error rather than the clean "Requests Portal Disabled" screen.
- From the first sign-in onward (URL now persisted) the gate applies pre-auth on every launch/foreground, as verified live.

This is accepted for v1: the realistic audience (owner + family) are returning users with a persisted URL, and closing the gap would require probing `/status` for the *typed/selected* URL on the sign-in screen (debounced, with URL-validity handling) — a SignInView↔SystemStore feature beyond this wiring feature's approved launch+foreground design. **Possible follow-up:** gate the sign-in screen by checking `/status` for the entered server URL.

## Testing & verification
- **Kit (headless `swift test`):** `SystemStore.portalEnabled` propagation is covered by `SystemStoreTests`/`SystemStatusTests`; add an explicit `portalEnabled == false` propagation assertion if one isn't already present. The gate *decision* is pure store state.
- **View:** `#Preview` for `PortalDisabledView`.
- **Live (iPhone 17, dev server):** confirm a `false` status replaces both the sign-in screen and the signed-in shell, and that a normal `true` status is unaffected. Force `portalEnabled=false` via the dev-server flag if supported, else a DEBUG-only injected fake. Per F2.4's precedent the unit test is the gate; the live check is confirmatory.

## Open questions
- [x] ~~Which endpoint serves `portalEnabled`, and is it callable without a token?~~ **Resolved: `GET /api/v1/status`, public** (no token needed).
- [x] ~~How reactive should the gate be?~~ **Resolved: launch + foreground refresh** (no continuous pre-auth polling).

## Dependencies
- [System & module discovery](../01-foundations/system-module-discovery.md), [Portal API client](../01-foundations/portal-api-client.md).
