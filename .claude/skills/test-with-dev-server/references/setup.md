# One-time setup for local dev-server testing

Do this once per machine, and once more per physical device. After it's done, routine runs only need the steps in `SKILL.md`.

## 1. Server prerequisites (`~/Git/SlipStream`)
- `make install` (Go deps + Bun packages).
- Start the backend **from the repo root** with dev mode on:
  ```
  go run ./cmd/slipstream --config config.yaml --dev-mode
  ```
  Run from the root so the backend finds the root `config.yaml` (gitignored) and the root-relative `./data`.
- **Do not use `make dev` / `make dev-mode`.** Their `dev-backend*` targets do `cd cmd/slipstream && go run .`, where the backend can't find the root `config.yaml` and panics. (Fixing those Makefile targets to run from the root, or to pass `--config`, would make them usable — but that's a change in the server repo.)
- The web app (`make dev-frontend`, `:3000`) is optional and only needed if you want the admin UI.

## 2. Dev mode (the sandbox) — enabled by the startup flag
`--dev-mode` (or `SLIPSTREAM_DEV_MODE=1`) turns dev mode on **at startup** — no web-UI toggle needed. It switches to a separate `*_dev.db`, mocks the indexer / download / notification clients, and seeds a small sample library (a handful of movies/series). It also copies your production portal users **and** the JWT secret into the dev DB, so your normal credentials work and tokens stay valid. Writes (create / cancel / watch) land only in `*_dev.db` and never touch real data.

## 3. A throwaway portal test user
The app signs in with a username + 4-digit PIN; even dev mode requires real credentials. Use a dedicated throwaway portal user (created in the admin web app) so your real PIN never lives in committed files — e.g. a `tester` user. Its values go in the `SLIPSTREAM_DEV_USERNAME` / `SLIPSTREAM_DEV_PIN` env vars (see §5); they are **not** hard-coded in this repo.

## 4. (Physical device only) Reach the server over the LAN
A phone cannot reach `localhost`, so it addresses the Mac by its Bonjour `.local` name:
- The dev `config.yaml` already sets `host: 0.0.0.0`, so the server is LAN-bound — no extra "external access" toggle needed. (If a setup ever binds loopback only, enable external access so it binds `0.0.0.0`.)
- Find your Mac's Bonjour name: `scutil --get LocalHostName` → use `http://<name>.local:8080`.
- Put the device on the same Wi-Fi. iOS prompts for **Local Network** access on first connect — allow it (the Debug build ships `NSLocalNetworkUsageDescription` for this).

## 5. Persisting the launch env (so the form auto-pre-fills)
Two equivalent homes for `SLIPSTREAM_BASE_URL` / `SLIPSTREAM_DEV_USERNAME` / `SLIPSTREAM_DEV_PIN`:
- **XcodeBuildMCP default env** (drives `launch_app_sim`): `session_set_defaults` with `env: {…}` and `persist: true` writes them to `.xcodebuildmcp/config.yaml` (gitignored). Then `launch_app_sim` pre-fills automatically.
- **Xcode Run scheme** (for runs launched from Xcode): `SlipStream` scheme → Arguments → Environment Variables → add the three vars.

Without either, use the in-app **Dev Servers** picker to fill the form.

## 6. Watch the simulator while testing
The simulator runs headless unless its window is open. In **Xcode 27 beta the Simulator lives under Device Hub** — open it to watch taps/navigation live. On older Xcode, open `Simulator.app` (e.g. XcodeBuildMCP `open_sim`).
> Note: if `snapshot_ui` / `tap` fail with a missing `SimulatorKit.framework`, the framework moved to `Contents/SharedFrameworks/` in recent Xcode while older XcodeBuildMCP looks in `Contents/Developer/Library/PrivateFrameworks/`. Fix by updating XcodeBuildMCP, or symlink the framework into the expected path.

## Troubleshooting
- `scripts/smoke.sh` fails on `/api/v1/status` → the backend isn't running / wrong URL/port. Confirm you started it **from the repo root** with `--dev-mode` (not `make dev`). Check `/api/v1/status` shows `"developerMode": true`.
- login returns no token → wrong dev user / PIN.
- device can't connect → wrong `.local` name, different Wi-Fi, or the Local Network prompt was denied (re-enable in iOS Settings → the app → Local Network).
- app shows the form but **Sign In stays disabled** → in Release the URL must be HTTPS; in Debug an `http://` URL must be a local host (`localhost`, `127.0.0.1`, or `*.local`). Fix the URL.
