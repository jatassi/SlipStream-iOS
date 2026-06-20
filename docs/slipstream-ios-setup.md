# SlipStream iOS — Project Setup

**v1 scope:** Portal companion. Browse the library and request media against SlipStream's JWT portal surface, authenticating with username + a 4-digit PIN. The **native app targets you and a few trusted family members**; the broader, less-trusted audience stays on SlipStream's existing responsive **web portal**. **One server-side change is in scope** — per-user `/ws` scoping (§5, and the companion plan in the server repo) — so the old "no server changes" assumption no longer holds; everything else is client-only. No paid Apple entitlements.
**Minimum target:** iOS / iPadOS **26**, Swift 6, SwiftUI.
**Platforms:** iPhone, iPad, and Mac via **"Designed for iPad"** — one app target, no separate Mac codebase. (tvOS/watchOS deliberately out of scope.)
**Workflow goal:** Claude Code drives the inner loop (write → build → run on simulator → read errors → iterate) headlessly; Xcode is reserved for signing, provisioning, and archive.

---

## 1. Stack

**Application**

| Concern | Choice | Why |
| --- | --- | --- |
| Language / UI | Swift 6, SwiftUI, `@Observable` | One adaptive SwiftUI layer serves all three platforms. |
| Architecture | Local SPM feature packages, one per media type | Mirrors SlipStream's module system; packages are platform-agnostic so all three targets share them. |
| Layout | Size-class-adaptive SwiftUI (`NavigationSplitView`, grids) | iPad adaptivity *is* the Mac experience under Designed for iPad — invest once, get both. |
| Networking | `URLSession` + async/await behind a typed client | No server OpenAPI spec exists (confirmed), so hand-mirror the portal types from `web/src/types/portal.ts`. |
| Auth | Username + 4-digit PIN → 30-day JWT; token in biometric-gated Keychain, Face ID local unlock | No paid entitlement needed. PIN authenticates to the server; Face ID is a local gate on token release. |
| Real-time | `URLSessionWebSocketTask` → `@Observable` event manager | Re-emits `/ws` events as invalidate-then-refetch, analogous to TanStack Query. Auth rides the `Sec-WebSocket-Protocol` header; depends on per-user server scoping (§5). |
| Images | Nuke | High poster/artwork throughput; `AsyncImage` is fine for a throwaway spike. |
| Persistence | In-memory + `URLCache` for v1 | Add SwiftData only if an offline library snapshot becomes a requirement. |
| Testing | Swift Testing (unit), XCUITest (UI) | UI tests run through XcodeBuildMCP. |
| Dependencies | SPM only | No CocoaPods/Carthage. |

**Tooling**

- **Claude Code** in the terminal as the primary driver.
- **XcodeBuildMCP** (standalone, Sentry-hosted) for headless build / test / simulator / log capture — no running Xcode process required.
- A **token-wrapping skill** (`ios-simulator-skill` or `xclaude-plugin`) so raw `xcodebuild` output is summarized to a line + an xcresult ID instead of flooding context. (XcodeBuildMCP now also ships its own first-party skill — evaluate that before bolting on a third-party wrapper.)
- **`CLAUDE.md`** in the iOS repo pinning scheme, simulator, build/test commands, and the SlipStream API contract.
- **Xcode 26.3** retained only for signing, provisioning, capabilities, and archive.
- **Separate repo** (`SlipStream-iOS`), with the SlipStream API contract vendored or referenced from the server repo.

---

## 2. Prerequisites

- macOS with **Xcode 26.3+** installed (`xcode-select -p` should resolve; run the IDE once to accept the license and install simulators).
- **Node.js** on PATH (XcodeBuildMCP runs via `npx`).
- **Claude Code** installed and authenticated.
- A reachable **SlipStream instance** with the portal enabled, served over **HTTPS with a publicly-trusted cert**. The server itself is plain HTTP on `:8080`; your existing reverse proxy terminates TLS. iOS App Transport Security blocks plain `http://`, so the proxied `https://` origin is what the app talks to — no ATS exceptions needed. (Also confirm the proxy forwards the WebSocket `Upgrade` **and** `Sec-WebSocket-Protocol` header; the latter carries the JWT for `/ws`.)
- A portal user account for testing.
- A unique **bundle identifier**. A **free Apple Personal Team** is sufficient — Face ID needs no special entitlement, and biometric-gated Keychain works on a free team. **Free-team limits to plan for:** provisioning profiles expire every **7 days** (the app stops launching → rebuild/reinstall from your Mac weekly), max **3 apps installed concurrently**, and **no TestFlight or App Store** (those need the paid $99/yr Apple Developer Program). This is why the native app is scoped to you + a couple of devices you can re-sign; everyone else uses the web portal.
- An **Apple Silicon Mac** to run the Designed-for-iPad build — that path is ARM-only and won't run on Intel Macs.

---

## 3. Repository & targets

Create the app shell in Xcode once (project generation is the one step not worth scripting):

1. New → App, SwiftUI lifecycle, Swift, **iOS 26.0** deployment target, bundle id e.g. `dev.jatassi.slipstream`. Select **iPhone and iPad** under supported devices.
2. In the target's **Supported Destinations**, add **Mac (Designed for iPad)**. That's the entire macOS story — no Catalyst, no second target, no `#if os(macOS)`. The same iPad binary runs natively on Apple Silicon Macs in a resizable window.
3. Commit the generated `.xcodeproj`, then move all feature code into local SPM packages so Claude works mostly in plain Swift files rather than the project file.

**What "Designed for iPad" does and doesn't give you.** The Mac runs your iPad app through the iOS runtime, so a well-built adaptive iPad layout *is* the Mac UI — the design work lives entirely in iPad size-class adaptivity, not in Mac-specific code. You actually get more for free than you might expect: the system auto-populates a **real menu bar**, supports **multiple windows** once you set `UIApplicationSupportsMultipleScenes`, and renders a **Settings bundle** as a Mac preferences panel. What you genuinely *don't* get is native `NSToolbar` behavior — the one Mac idiom with no automatic equivalent. For a personal media companion that's an acceptable trade; if the Mac experience later starts to grate, the upgrade path is Mac Catalyst, then a native macOS destination — but neither is needed now. A handful of iOS-only APIs are unavailable or no-op on Mac (mostly device-hardware things you won't hit here); guard those with `ProcessInfo.processInfo.isiOSAppOnMac` if one ever surfaces.

Target layout:

```
SlipStream-iOS/
  SlipStream.xcodeproj
  App/                      # @main entry, app-level composition, routing
  Packages/
    SlipStreamKit/          # API client, models, auth, websocket, keychain
    DesignSystem/           # shared SwiftUI components, theming, image cache
    Feature-Library/        # browse library (movie + tv)
    Feature-Requests/       # request flow + status (quota display cut from v1)
    Feature-Auth/           # PIN sign-in + Face ID unlock
  CLAUDE.md
  .mcp.json
  .claude/
    skills/                 # token-wrapping simulator skill (if installed per-project)
```

The `Feature-*` packages intentionally map onto SlipStream's per-module frontend config objects. Adding the Music module later is then a new `Feature-Music` package plus model additions, not a structural change. (Discover which modules are actually enabled at runtime from `GET /api/v1/system` rather than hardcoding movie/tv.)

---

## 4. Claude Code workflow setup

### 4.1 XcodeBuildMCP (project scope)

Add it at **project scope** so the config lives in a committed `.mcp.json` and travels with the repo. From the repo root:

```bash
claude mcp add --scope project xcodebuildmcp -- npx -y xcodebuildmcp@latest mcp
```

> Confirm the exact package name / invocation against the current XcodeBuildMCP README — the project moved to Sentry hosting and the npx entrypoint and tool catalog change between releases. Note the **`mcp` subcommand**: recent versions are a dual CLI+server, so the server is started with `xcodebuildmcp@latest mcp`, not the bare package. The resulting `.mcp.json` should look like:

```json
{
  "mcpServers": {
    "xcodebuildmcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest", "mcp"],
      "env": {
        "XCODEBUILDMCP_ENABLED_WORKFLOWS": "simulator,project-discovery,ui-automation,debugging"
      }
    }
  }
}
```

Enabling only the workflows you use keeps the tool surface (and context) lean. Add `device` later when you want on-device builds. If you adopt XcodeBuildMCP's own project config, pin defaults so the agent stops re-discovering them — the file is **`.xcodebuildmcp/config.yaml`**:

```yaml
# .xcodebuildmcp/config.yaml — confirm schema against the README
schemaVersion: 1
enabledWorkflows:
  - simulator
  - ui-automation
  - debugging
sessionDefaults:
  scheme: SlipStream
  projectPath: ./SlipStream.xcodeproj
  simulatorName: iPhone 17
```

> MCP scope reference (verified against Claude Code docs): `local` is private to you in the current project (stored in `~/.claude.json`), `project` is shared via committed `.mcp.json`, `user` applies across all your projects. Options precede the server name; `--` separates the name from the launch command.

### 4.2 Agent skills

Skills are model-invoked `SKILL.md` capabilities that add *judgment*, not plumbing. The MCP is the driver; a skill earns an always-on context slot only if it improves the code Claude writes today, doesn't duplicate the MCP/CLAUDE.md layer, and doesn't fight a decision already made. By that bar the set stays deliberately small.

**Install now**

> Install mechanism: `npx skills add` is **Vercel Labs'** cross-agent skills CLI (it resolves a repo's nested `SKILL.md` and drops it in `.claude/skills/`). Don't `git clone` these repos straight into `.claude/skills/` — both are plugin *marketplaces* with the skill nested under `skills/<name>/`, so a bare clone won't load. The native-plugin alternative is `/plugin marketplace add <owner/repo>` then `/plugin install <skill>@<marketplace>`.

*Token-wrapping simulator skill* — so build output is summarized rather than dumped:

```bash
npx skills add conorluddy/ios-simulator-skill
```

Restart Claude Code; it loads automatically. Builds then return a one-line summary plus an xcresult ID, and Claude pulls errors/warnings/full logs on demand instead of inline. (XcodeBuildMCP now ships its own first-party skill at `skills/xcodebuildmcp/SKILL.md`; if you adopt it you may not need a separate wrapper at all.)

*SwiftUI quality (twostraws `swiftui-pro`)* — catches the SwiftUI anti-patterns agents fall into (deprecated APIs, VoiceOver-invisible controls, performance traps):

```bash
npx skills add twostraws/swiftui-agent-skill --skill swiftui-pro
```

**Architecture — handled in CLAUDE.md, not a skill.** The MV/`@Observable` rules live in the Conventions block below (§4.3) as always-on context at zero extra cost. An architecture skill only earns its slot once a codebase is large enough to drift; a solo portal app isn't.

**Deferred — install when the trigger fires (don't pre-load):**

| Skill | Trigger |
| --- | --- |
| twostraws **Swift Testing** skill (`swift-testing-pro`) | First real `Feature-*` test target exists. Early on, the XcodeBuildMCP screenshot-and-read loop is the fast feedback, not a test suite. |
| **qa-testing-ios** (flake control, xcresult parsing, CI template) | You set up CI / start fighting flaky UI tests. Note it overlaps XcodeBuildMCP's simulator-driving — let the MCP drive, the skill advise. |
| **kylebrowning swift-assist** (a11y-identifier auto-fix + visual regression; distributed from `grantiva/swift-assist`, needs the external Grantiva CLI) | You want to bootstrap UI-test coverage across screens. |
| **dpearson2699/swift-ios-skills** (iOS 26+ collection) | Cherry-pick individual skills (networking, accessibility) on demand — never install the bundle wholesale. |

**Evaluate separately, not as an add-on:** **CharlesWiltgen/Axiom** is a full Apple-platform framework (254 skills, 41 agents, plus its own `xclog` console capture and `xcsym` crash symbolication). Its log-capture and build-diagnosis tooling overlaps XcodeBuildMCP, so adopting it is an either/or with the MCP-as-driver setup — a deliberate "go comprehensive" choice if this app grows, not a lean pick to bolt on now.

**Skip:** TCA skill collections (johnrogers/claude-swift-engineering and others) — mature, but they impose The Composable Architecture, which fights the MV decision. The `superpowers` framework's strict TDD workflow, same logic: it imposes a methodology you didn't choose (it's a broad agentic toolkit, but TDD is the part that would bind you).

### 4.3 CLAUDE.md

Drop this in the repo root and expand as the contract firms up:

```markdown
# SlipStream iOS

SwiftUI portal companion for the self-hosted SlipStream media manager.
Targets the portal surface only (username + 4-digit PIN → 30-day JWT). iOS 26+, Swift 6.

## Build / test (use XcodeBuildMCP — do not shell out to xcodebuild directly)
- Build (sim):  mcp__xcodebuildmcp__build_sim
- Test (sim):   mcp__xcodebuildmcp__test_sim
- Build (Mac):  build for the "My Mac (Designed for iPad)" destination — runs natively, no simulator
- Clean:        mcp__xcodebuildmcp__clean   (before major rebuilds)
- Logs:         mcp__xcodebuildmcp__start_sim_log_cap / stop_sim_log_cap
- Scheme: SlipStream   Simulators: iPhone 17, iPad Pro 13-inch (M4)

## API contract (read from the server; do not invent)
- Base URL: your HTTPS reverse-proxy origin. Portal endpoints live under /api/v1/requests/*.
- Types source of truth: server web/src/types/portal.ts (hand-mirror to Codable);
  clients in web/src/api/portal/. No OpenAPI spec exists.
- Auth: POST /api/v1/requests/auth/login {username, password} -> {token, user, isAdmin}.
  The "password" field IS the 4-digit PIN. JWT lasts 30 days; there is no refresh token.
- WebSocket: /ws, JWT passed via the Sec-WebSocket-Protocol header. Messages are
  {type, payload, timestamp, module, entityType, entityId, action}; mirror the per-module
  wsInvalidationRules from web/src/modules/*/index.ts. (Server-side per-user scoping pending.)

## Conventions
- Feature code lives in Packages/*; keep the .xcodeproj edits minimal.
- One adaptive SwiftUI layer serves iPhone, iPad, and Mac. Use size classes and
  NavigationSplitView; do not branch on platform unless an API is truly unavailable.
- Models are Codable mirrors of the SlipStream portal API. Source of truth:
  server web/src/types/portal.ts. Do not invent endpoints or fields.
- Networking via URLSession + async/await behind SlipStreamKit's typed client.
- JWT lives in Keychain only — never UserDefaults.
- WebSocket events from /ws drive invalidate-then-refetch; do not poll.

## Definition of done for a feature
Builds clean on the iPhone and iPad simulators and the Mac (Designed for iPad)
destination, Swift Testing units pass, and the screen renders with a live portal
token against a real SlipStream instance.
```

### 4.4 The headless loop

Run Claude Code from the repo, start in plan mode for anything non-trivial, and let it build/run/iterate through the MCP:

```bash
cd SlipStream-iOS
claude --permission-mode plan
```

A typical turn: describe the screen → Claude writes Swift in a `Feature-*` package → builds via `build_sim` → reads the summary → boots the sim, installs, launches, captures logs → fixes and repeats, all without you opening Xcode. The Mac (Designed for iPad) destination builds and runs *natively* — no simulator — so Claude can exercise the Mac build directly on the same machine, which is a nice bonus over the per-platform simulator dance.

---

## 5. SlipStream API contract

The app talks to **`/api/v1`** (REST) and **`/ws`** (WebSocket). Portal endpoints sit under the **`/api/v1/requests/*`** prefix (e.g. `POST /api/v1/requests/auth/login`, `GET /api/v1/requests/library/movies`, `GET /api/v1/requests/search/movie`, `POST /api/v1/requests`, `GET /api/v1/requests/:id`, `GET /api/v1/requests/inbox`). The contract is not invented here — it is read from the server:

- **Portal endpoints, auth, quotas:** `internal/portal/` (handlers, provisioner, user/quota logic) and the portal clients in `web/src/api/portal/`.
- **Models / field shapes:** the canonical typed contract is **`web/src/types/portal.ts`** — 326 lines of hand-written interfaces (`LoginRequest`, `Request`, `PortalMovieSearchResult`, `AvailabilityInfo`, …). Mirror these as Swift `Codable` structs in `SlipStreamKit`. `RequestStatus` is an 8-state enum: `pending | approved | denied | searching | downloading | failed | available | cancelled`.
- **WebSocket events:** the per-module `ModuleConfig.wsInvalidationRules` in `web/src/modules/<id>/index.ts` (regex patterns like `movie:(added|updated|deleted)` → query keys to invalidate, applied in `web/src/stores/ws-message-handlers.ts`) tell you which events map to which data, so the Swift event manager can mirror the same invalidate→refetch routing. Messages have the shape `{type, payload, timestamp, module, entityType, entityId, action}`, and the JWT is presented to `/ws` via the **`Sec-WebSocket-Protocol`** header.
- **Enabled modules:** discover which modules (movie/tv) are active from `GET /api/v1/system` rather than hardcoding.

**Model generation:** the Echo backend does **not** emit an OpenAPI spec (no swaggo/oapi-codegen, no annotations, no spec artifact — confirmed). So `swift-openapi-generator` is **not** an option; hand-mirror the portal types from `web/src/types/portal.ts` and treat the server source as canonical. Since the server is actively developed, add a lightweight drift check (e.g. vendor `portal.ts` into the iOS repo and a CI step that diffs it against the server's).

**Server dependency — per-user `/ws` scoping.** Today `/ws` is a single global broadcast: any authenticated connection receives every event (other users' requests, admin `devmode`/scheduler/log traffic). For the trusted native audience that's just noise the client can filter, but because the same socket also serves the less-trusted web users, the scoping should move server-side. This is the one in-scope server change; it is specced separately in the server repo at `docs/portal-websocket-scoping-plan.md`. Wire the iOS event manager to live updates after that lands (until then, the client should defensively filter to its own events).

---

## 6. Auth implementation

The portal authenticates with **username + a 4-digit PIN** and returns a **30-day JWT**. Face ID is layered on top as a *local* convenience — it never talks to the server. Keep the two roles distinct:

- **The PIN authenticates to SlipStream.** It is the only credential the server sees — sent as the `password` field on login (the server enforces exactly 4 digits) — and it's what mints the JWT.
- **Face ID authorizes release of the stored token from the Keychain.** It is a device-local gate, nothing more. ("Face ID logs me in" is the wrong mental model and leads to muddled code.)

Neither requires a paid entitlement: Face ID needs only an `NSFaceIDUsageDescription` string in Info.plist, and biometric-gated Keychain works on the free Personal Team.

**Token lifetime is settled — and it simplifies everything.** The portal mints a **30-day JWT with no refresh token** (`internal/auth/service.go`). There is no refresh endpoint to call and none to build, so the auth flow collapses to "store the token, re-enter the PIN monthly":

**Flow**

1. **First launch** — user enters username + 4-digit PIN once → `POST /api/v1/requests/auth/login` → receive the 30-day JWT.
2. **Store the JWT** (not the PIN) in the Keychain behind a biometric access-control flag (see below), with accessibility `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
3. **Subsequent launches** — `LAContext` evaluates Face ID, which unlocks the Keychain item; pull the token without re-typing the PIN.
4. **On expiry (~monthly)** — the stored token is simply expired; prompt for the 4-digit PIN again and re-login. No reusable secret is persisted, and there is nothing to refresh.

**Decisions**

- **Access-control flag:** `.userPresence` is the friendlier default — it survives biometric re-enrollment and allows device-passcode fallback. Choose `.biometryCurrentSet` instead if you want the stricter posture, where re-enrolling Face/Touch invalidates the stored token and forces a fresh PIN login.
- **Evaluation policy:** prefer `deviceOwnerAuthentication` (allows passcode fallback when Face ID fails) over `deviceOwnerAuthenticationWithBiometrics` (biometrics only) — better UX for a media app.
- **Across platforms:** the same `LAContext` flow resolves to Face ID on iPhone/iPad, Touch ID on Macs that have it, and the device password on Macs that don't. Choosing `deviceOwnerAuthentication` above means this "just works" everywhere with no platform branching — the design is already Mac-ready.

**Security note — the credential is 4 digits.** The entire server-side secret is a 4-digit PIN (10⁴ space). What stands between it and brute force is the server's login rate-limiter (`AuthLimiter`) plus TLS in transit — not the iOS Keychain, which only protects the already-minted token at rest. For a personal app behind your own TLS with a trusted native audience that's an acceptable posture, but PIN strength is the weak link, and hardening it (longer PIN, lockout) is a server-side change if you ever want it.

**Trade vs passkeys:** the server already supports passkeys (WebAuthn) and in fact promotes PIN as the *primary* sign-in with passkey as a secondary path — so PIN-first is the server's own direction, not a legacy fallback. Native passkeys are deliberately out of scope here: they require the **Associated Domains** entitlement, which is unavailable on a free Personal Team (it's a managed capability provisioned only through the paid Developer Program). Skipping them removes Associated Domains, the AASA file, and the paid-membership dependency entirely.

> **Passkeys (later, paid tier).** If you ever take the paid Developer Program, WebAuthn passkeys via `AuthenticationServices` (`ASAuthorizationPlatformPublicKeyCredentialProvider`) become available — they need the Associated Domains entitlement (included in the paid program at no extra cost) plus an `apple-app-site-association` file served at `https://<host>/.well-known/apple-app-site-association`. Out of scope for v1.

---

## 7. Signing & distribution (Xcode-bound)

These stay in Xcode / GUI and are intentionally out of the headless loop:

- Signing certificates and provisioning profiles. (No Associated Domains capability in v1 — Face ID needs no entitlement.)
- **Free Personal Team is the v1 path.** You sign and run on your own (and a couple of trusted family) devices with just your Apple ID — no $99/yr. The cost is operational: provisioning profiles expire every **7 days**, so the app stops launching until you rebuild/reinstall from your Mac, and you're capped at **3 installed apps**. That's tolerable for your own device(s) but impractical to push onto family members who aren't in front of your Mac weekly — those users stay on the web portal. There is **no TestFlight or App Store path on a free team**.
- **If/when this chafes, the upgrade is the paid Apple Developer Program ($99/yr):** it removes the 7-day treadmill, unlocks **TestFlight** (up to 10k external testers, one beta review) and the App Store, and — as a side effect — makes Associated Domains/passkeys and APNs push available at no extra cost. That's the moment to revisit push notifications and passkeys.
- **Mac (Designed for iPad)** needs no separate signing track — it's the same iOS app, signed once. Running it on your own Apple Silicon Mac during development is free.

For a personal-distribution app on a free team, your "distribution" is sideloading to your own devices; the broader audience is served by the web portal, not the native app.

---

## 8. Open items to confirm

1. ~~OpenAPI spec~~ — **Resolved: no.** The Echo backend emits no OpenAPI spec; hand-mirror `web/src/types/portal.ts` (Section 5).
2. ~~Portal endpoint inventory~~ — **Resolved.** Portal surface is under `/api/v1/requests/*`, read from `internal/portal/`. (Browse: `/library/{movies,series}`; search: `/search/{movie,series,series/seasons}`; requests: `GET/POST /api/v1/requests`, `/:id`, `/:id/watch`, `/downloads`; inbox: `/inbox`, `/inbox/count`.)
3. ~~Token lifetime~~ — **Resolved: 30-day JWT, no refresh token.** Store the JWT behind Face ID; the PIN resurfaces only on monthly expiry (Section 6).
4. **XcodeBuildMCP invocation** — verify against the current README: the server starts with the **`mcp` subcommand**, tool names are `build_sim` / `test_sim` / `start_sim_log_cap` / `stop_sim_log_cap`, and config lives in `.xcodebuildmcp/config.yaml`.
5. **Simulator name** — set `sessionDefaults.simulatorName` to a runtime actually installed (`xcrun simctl list devices`).
6. **Per-user `/ws` scoping (server)** — the one in-scope server change; design it via `docs/portal-websocket-scoping-plan.md` in the server repo before wiring the iOS event manager to live updates.
7. **Confirm target devices run iOS 26** — the iOS 26 minimum drops A12 hardware (iPhone XR/XS, 7th-gen iPad); make sure your and your family's devices qualify, and that the Mac is Apple Silicon.

---

## 9. Deferred (revisit only if you take the paid tier)

These are explicitly **not** in v1, gathered here so the v1 surface stays small:

- **Quota display** — there is no portal-scoped quota endpoint today (quota reads are admin-only, and an over-quota request still returns `201` rather than erroring), so a quota meter isn't buildable against the current API without a small server addition. Cut from v1.
- **Push notifications** — "your movie is ready" as a real push needs APNs, which is paid-tier-only. v1 relies on live WebSocket updates while foregrounded (plus the in-app `/inbox` history if you choose to surface it).
- **Passkeys** — see §6; needs Associated Domains (paid tier).
