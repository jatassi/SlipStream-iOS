# SlipStream iOS

SwiftUI portal companion for the self-hosted SlipStream media manager.
Targets the portal surface only. iOS 26+, Swift 6.

## Build / test (use XcodeBuildMCP — do not shell out to xcodebuild directly)
- Build (sim):  mcp__xcodebuildmcp__build_sim
- Test (sim):   mcp__xcodebuildmcp__test_sim (see `/test-with-dev-server` skill)
- Build (Mac):  build for the "My Mac (Designed for iPad)" destination — runs natively, no simulator
- Clean:        mcp__xcodebuildmcp__clean   (before major rebuilds)
- Logs:         mcp__xcodebuildmcp__start_sim_log_cap / stop_sim_log_cap
- Scheme: SlipStream   Simulators: iPhone 17, iPad Pro 13-inch (M4)

## Linting
- swift-format owns formatting; SwiftLint owns semantic lint only (configs: `.swift-format`, `.swiftlint.yml`).
- `make format` (apply) · `make lint` (check) · `make install-hooks` (per checkout).
- Pre-commit hook checks staged files and blocks; it never rewrites code.
- SwiftLint via Homebrew; swift-format from the toolchain. Tests use a relaxed nested config.

## API contract (read from `~/Git/SlipStream`; do not invent)
- Base URL: `https://slipstream.atassi.org/` Portal endpoints live under /api/v1/requests/*.
- Types source of truth: web/src/types/portal.ts - clients in web/src/api/portal/.
- Auth: POST /api/v1/requests/auth/login {username, password} -> {token, user, isAdmin}.
  The "password" field IS the 4-digit PIN. JWT lasts 30 days; there is no refresh token.
- Real-time: poll the active views (requests, downloads, inbox count) every ~3s while
  foregrounded, mirroring the web frontend. The portal /ws is admin-only; do not use it.

## Conventions
- Feature code lives in Packages/*; keep the .xcodeproj edits minimal.
- One adaptive SwiftUI layer serves iPhone, iPad, and Mac. Use size classes and
  NavigationSplitView; do not branch on platform unless an API is truly unavailable.
- Models are Codable mirrors of the SlipStream portal API.
- Networking via URLSession + async/await behind SlipStreamKit's typed client.
- JWT lives in Keychain only.

## Mandatory Directives
- When spawning subagents, always prefix their labels with the model name in brackets (e.g., `[Opus (1M)] Do the thing`, `[Sonnet] Do the less complicated thing`)
- This is a solo repo, you have free reign to commit and push directly to `main`
- Run the `/code-review` skill before merging non-`docs/` changes to `main` and triage findings with bias towards acceptance.
- Always squash merge to `main`
- Never inline-disable a linter rule (e.g. `// swiftlint:disable`) without extremely strong justification — fix the code or adjust the shared config instead.
