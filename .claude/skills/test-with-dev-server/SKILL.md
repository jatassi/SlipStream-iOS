---
name: test-with-dev-server
description: Use when running or testing the SlipStream iOS app against a local SlipStream dev server — real login/requests/downloads/inbox against dev-mode seeded data on simulator, Mac, or a physical device; or when the user mentions localhost:8080, a `.local` dev server, server "dev mode", or the SLIPSTREAM_BASE_URL / SLIPSTREAM_DEV_* env vars.
---

# Test with the local dev server

Run the **real** SlipStream iOS app against a **local** SlipStream dev server, so you exercise live login, requests, downloads, and inbox against seeded data — the inner dev loop, not unit tests with stubs. Debug-only; Release is untouched and stays HTTPS-strict.

This relies on the **live-testing enablers** that live on `main`: the Debug ATS exception, the sign-in **Dev Servers** picker, and the `SLIPSTREAM_*` launch overrides.

## Targets — how each reaches the server

| Target | Server URL | Needs |
|---|---|---|
| iOS Simulator | `http://localhost:8080` | nothing extra |
| Mac (Designed for iPad) | `http://localhost:8080` | nothing extra |
| Physical iPhone / iPad | `http://<your-mac>.local:8080` | device on the same Wi-Fi (the dev `config.yaml` already binds `0.0.0.0`) |

First time on this machine — or first time on a given physical device — do the one-time setup first: [references/setup.md](references/setup.md). Routine runs only need the steps below.

## Steps

1. **Start the dev server (sandbox) from the repo root.** In `~/Git/SlipStream`, run the backend from the **repo root** with dev mode enabled at startup:
   ```
   go run ./cmd/slipstream --config config.yaml --dev-mode
   ```
   (equivalently `SLIPSTREAM_DEV_MODE=1 go run ./cmd/slipstream --config config.yaml`). `--dev-mode` switches to a separate, **seeded** `*_dev.db` with mocked indexer / download / notification clients and turns dev mode on **at startup** — no web-UI toggle. Run from the repo root so the backend finds the root `config.yaml` (gitignored) and the root-relative `./data`.
   - **Do not use `make dev` / `make dev-mode`** — their `dev-backend*` targets `cd cmd/slipstream` first, where the backend can't find the root `config.yaml` and panics.
   - The web app (`make dev-frontend`, `:3000`) is optional — with dev mode on via the flag you don't need the admin UI.

   Done when this skill's `scripts/smoke.sh` exits 0 (reachability + login + one authenticated poll). Physical device: smoke-test the LAN URL — `<skill>/scripts/smoke.sh http://<your-mac>.local:8080`.

2. **Build, run, and watch.** Use XcodeBuildMCP — per CLAUDE.md, never shell out to `xcodebuild`.
   - **Watch it live:** open the Simulator window so you can see the run. In **Xcode 27 beta it's under Device Hub**; on older Xcode, open Simulator.app (e.g. `open_sim`). Otherwise the sim runs headless.
   - `build_run_sim` (scheme `SlipStream`, configuration `Debug`, simulator `iPhone 17`, or the Mac / device destination) builds + installs + launches — but it **does not pass app env vars**. To pre-fill the sign-in form, relaunch with **`launch_app_sim`**, which applies the persisted launch env (`SLIPSTREAM_BASE_URL` / `SLIPSTREAM_DEV_USERNAME` / `SLIPSTREAM_DEV_PIN` from `.xcodebuildmcp/config.yaml`), or pass `env:` explicitly.
   - No env configured? Tap **Dev Servers → Localhost (sim/Mac)** in the sign-in screen — it fills the URL and, for a local target, the throwaway credentials.

   Done when the app is at the sign-in screen with the server URL — and, for a local target, the credentials — filled in.

3. **Sign in and smoke-verify.** Tap **Sign In** (pre-fill never auto-submits, so the real login → JWT → Keychain path runs). Done when the app reaches the signed-in screen (e.g. "Signed in as &lt;user&gt;" with profile details). Post-login is currently a profile placeholder — the requests / downloads / inbox feature views aren't built yet, though their endpoints are live (`smoke.sh` covers one).

## Reference

- **Credentials & the env seam** — `SLIPSTREAM_BASE_URL`, `SLIPSTREAM_DEV_USERNAME`, `SLIPSTREAM_DEV_PIN`, parsed by `DevLaunchConfig` in `SlipStreamKit/Dev/`. Persisted as the XcodeBuildMCP default launch env in `.xcodebuildmcp/config.yaml` (gitignored), so `launch_app_sim` auto-pre-fills the form. Same seam future automated integration tests use: set them and drive `AuthStore.signIn` directly, no UI. An invalid `SLIPSTREAM_BASE_URL` is ignored and the form falls back to the persisted URL.
- **Dev mode is a seeded sandbox** — `--dev-mode` serves a separate `*_dev.db` with a small sample library and mock indexer / download / notification clients, so search and request create/cancel/watch and download progress work without touching real data or services.
- **Presets** — the Debug **Dev Servers** picker offers `Localhost (sim/Mac)`, `Mac on LAN (device)` (`.local`), and `Production`. Only the local (http) presets pre-fill credentials; Production never does.
- **Watch live** — the Simulator window is under **Device Hub** in Xcode 27 beta.
- **Release safety** — every affordance here is `#if DEBUG` or Debug-build-config-only. Nothing to undo before shipping: Release has no picker, no pre-fill, no ATS exception, and is HTTPS-strict.
- **One-time setup, test-user creation, device LAN, troubleshooting** — [references/setup.md](references/setup.md).
