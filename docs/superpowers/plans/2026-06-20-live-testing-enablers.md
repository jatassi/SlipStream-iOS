# Live-Testing Enablers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iOS app capable of talking to a local SlipStream dev server (`http://localhost:8080`, `http://<mac>.local:8080`) in Debug builds — via an ATS exception, a sign-in environment picker, launch-arg overrides, and dev-credential pre-fill — while leaving Release builds byte-for-byte as strict as today.

**Architecture:** All new *logic* (env-var parsing, URL validation, presets) lands as small, public, unit-tested value types in `SlipStreamKit/Dev/`. The SwiftUI sign-in layer (`FeatureAuth`) consumes them; the dev-only affordances (picker, credential pre-fill, launch-URL override) are wrapped in `#if DEBUG`. The ATS relaxation is a Debug-only **partial Info.plist** referenced by `INFOPLIST_FILE` in the app target's Debug config only — Release keeps the pure generated plist. The launch env vars (`SLIPSTREAM_BASE_URL`, `SLIPSTREAM_DEV_USERNAME`, `SLIPSTREAM_DEV_PIN`) are the single seam shared by manual testing (pre-fill) and future automated integration tests (inject + auto-submit).

**Tech Stack:** Swift 6, SwiftUI, SwiftPM packages, Swift Testing (`import Testing`), XcodeBuildMCP for app builds.

## Global Constraints

- iOS 26+, Swift 6 (`SWIFT_VERSION = 6.0`); packages use swift-tools 6.2.
- Feature code lives in `Packages/*`; keep `.xcodeproj` edits minimal (this plan touches the pbxproj exactly once — one line in the Debug config).
- JWT lives in Keychain only; the server base URL is non-secret and lives in `UserDefaults` via `ServerConfigStore`. Dev credentials are throwaway and never persisted to the Keychain by this work.
- **Release builds must remain unchanged:** no ATS exception, HTTPS-only sign-in, no dev picker. Every Debug-only change is gated by `#if DEBUG` or by a build setting present only in the Debug configuration.
- **Running tests:** the new unit tests live in the `SlipStreamKitTests` SwiftPM target, which declares `.macOS(.v14)` and therefore runs on the macOS host. Use `swift test --package-path Packages/SlipStreamKit` for the TDD loop — this is SwiftPM, **not** a direct `xcodebuild` invocation, so it complies with CLAUDE.md. App-level build verification uses XcodeBuildMCP (`build_sim`), per CLAUDE.md. Scheme: `SlipStream`; simulators: iPhone 17, iPad Pro 13-inch (M4).
- Match existing test conventions: `import Testing` + `@Suite` / `@Test` / `#expect`; `@testable import SlipStreamKit`.
- **Linting (active pre-commit hook):** swift-format owns ALL formatting; SwiftLint (`--strict`) owns semantic lint. The hook (installed via `make install-hooks`) blocks any commit that fails `make lint`. **Before every commit, run `make format` then `make lint` (must exit 0).** Never inline-disable a linter rule. swift-format uses 2-space indentation and alphabetized imports — write new code that way, but `make format` will normalize regardless, so exact continuation indentation in this plan's snippets is illustrative.

---

## File Structure

**New (logic + tests in SlipStreamKit):**
- `Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/DevLaunchConfig.swift` — parse launch env vars into typed overrides.
- `Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/ServerURLValidator.swift` — scheme/host acceptance + the `DevSupport.allowsInsecureLocalServers` compile flag.
- `Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/DevServerPreset.swift` — named one-tap server targets.
- `Packages/SlipStreamKit/Tests/SlipStreamKitTests/DevLaunchConfigTests.swift`
- `Packages/SlipStreamKit/Tests/SlipStreamKitTests/ServerURLValidatorTests.swift`
- `Packages/SlipStreamKit/Tests/SlipStreamKitTests/DevServerPresetTests.swift`

**New (build config):**
- `App/SlipStream-Debug-Info.plist` — partial Info.plist: ATS local-networking exception + local-network usage string.

**Modified:**
- `SlipStream.xcodeproj/project.pbxproj` — add `INFOPLIST_FILE` to the app target's **Debug** config only (block `…0111…`, `name = Debug`, after line 273).
- `Packages/Feature-Auth/Sources/FeatureAuth/SignInView.swift` — validator-backed `canSubmit`; Debug picker, credential pre-fill, and launch-URL override.
- `docs/TRACKER.md` — record this enabler feature.

**Interfaces produced (referenced by later tasks):**
- `DevLaunchConfig(environment:)` → `.baseURLOverride: URL?`, `.devUsername: String?`, `.devPIN: String?`; `DevLaunchConfig.current`.
- `DevSupport.allowsInsecureLocalServers: Bool`.
- `ServerURLValidator.isAcceptable(_ url: URL, allowInsecureLocal: Bool) -> Bool`; `ServerURLValidator.isLocalHost(_:) -> Bool`.
- `DevServerPreset(id:name:urlString:)`; `.localhost`, `.production`, `.macOnLAN(from:)`, `.all(config:) -> [DevServerPreset]`.

---

### Task 1: `DevLaunchConfig` — launch env-var parsing

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/DevLaunchConfig.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/DevLaunchConfigTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `DevLaunchConfig(environment: [String: String])` with `baseURLOverride: URL?`, `devUsername: String?`, `devPIN: String?`, and static `current`.

- [ ] **Step 1: Write the failing test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/DevLaunchConfigTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct DevLaunchConfigTests {
    @Test func parsesAllValues() {
        let cfg = DevLaunchConfig(environment: [
            "SLIPSTREAM_BASE_URL": "http://localhost:8080",
            "SLIPSTREAM_DEV_USERNAME": "tester",
            "SLIPSTREAM_DEV_PIN": "1234",
        ])
        #expect(cfg.baseURLOverride == URL(string: "http://localhost:8080"))
        #expect(cfg.devUsername == "tester")
        #expect(cfg.devPIN == "1234")
    }

    @Test func emptyEnvironmentYieldsNils() {
        let cfg = DevLaunchConfig(environment: [:])
        #expect(cfg.baseURLOverride == nil)
        #expect(cfg.devUsername == nil)
        #expect(cfg.devPIN == nil)
    }

    @Test func blankStringsAreTreatedAsAbsent() {
        let cfg = DevLaunchConfig(environment: [
            "SLIPSTREAM_BASE_URL": "",
            "SLIPSTREAM_DEV_USERNAME": "",
            "SLIPSTREAM_DEV_PIN": "",
        ])
        #expect(cfg.baseURLOverride == nil)
        #expect(cfg.devUsername == nil)
        #expect(cfg.devPIN == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/SlipStreamKit --filter DevLaunchConfigTests`
Expected: FAIL — `cannot find 'DevLaunchConfig' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/DevLaunchConfig.swift`:

```swift
import Foundation

/// Developer launch overrides read from the process environment, so live testing can
/// target a local SlipStream dev server without hand-typing URLs or credentials.
///
/// Set these in the `SlipStream` Run scheme's environment variables (Debug only):
/// - `SLIPSTREAM_BASE_URL`     e.g. `http://localhost:8080` or `http://my-mac.local:8080`
/// - `SLIPSTREAM_DEV_USERNAME` the throwaway portal test user
/// - `SLIPSTREAM_DEV_PIN`      that user's 4-digit PIN
///
/// Parsing lives here — not in the view — so it stays unit-testable with an injected
/// environment dictionary. The same env vars are the seam future automated integration
/// tests use to point the app at a server without driving any UI.
public struct DevLaunchConfig: Sendable, Equatable {
    public let baseURLOverride: URL?
    public let devUsername: String?
    public let devPIN: String?

    public init(environment: [String: String]) {
        func nonEmpty(_ key: String) -> String? {
            guard let value = environment[key], !value.isEmpty else { return nil }
            return value
        }
        self.baseURLOverride = nonEmpty("SLIPSTREAM_BASE_URL").flatMap(URL.init(string:))
        self.devUsername = nonEmpty("SLIPSTREAM_DEV_USERNAME")
        self.devPIN = nonEmpty("SLIPSTREAM_DEV_PIN")
    }

    /// Overrides from the live process environment.
    public static var current: DevLaunchConfig {
        DevLaunchConfig(environment: ProcessInfo.processInfo.environment)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages/SlipStreamKit --filter DevLaunchConfigTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/DevLaunchConfig.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/DevLaunchConfigTests.swift
git commit -m "feat: add DevLaunchConfig for launch-env-var overrides"
```

---

### Task 2: `ServerURLValidator` + `DevSupport`

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/ServerURLValidator.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/ServerURLValidatorTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `DevSupport.allowsInsecureLocalServers: Bool`; `ServerURLValidator.isAcceptable(_:allowInsecureLocal:) -> Bool`; `ServerURLValidator.isLocalHost(_:) -> Bool`.

- [ ] **Step 1: Write the failing test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/ServerURLValidatorTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct ServerURLValidatorTests {
    private func url(_ s: String) -> URL { URL(string: s)! }

    @Test func httpsIsAlwaysAcceptable() {
        #expect(ServerURLValidator.isAcceptable(url("https://slipstream.atassi.org"), allowInsecureLocal: false))
        #expect(ServerURLValidator.isAcceptable(url("https://example.com"), allowInsecureLocal: true))
    }

    @Test func httpToLocalIsAcceptableOnlyWhenAllowed() {
        let localhost = url("http://localhost:8080")
        let dotLocal = url("http://my-mac.local:8080")
        let loopback = url("http://127.0.0.1:8080")
        for u in [localhost, dotLocal, loopback] {
            #expect(ServerURLValidator.isAcceptable(u, allowInsecureLocal: true))
            #expect(!ServerURLValidator.isAcceptable(u, allowInsecureLocal: false))
        }
    }

    @Test func httpToPublicHostIsNeverAcceptable() {
        #expect(!ServerURLValidator.isAcceptable(url("http://slipstream.atassi.org"), allowInsecureLocal: true))
        #expect(!ServerURLValidator.isAcceptable(url("http://example.com"), allowInsecureLocal: true))
    }

    @Test func missingSchemeOrHostIsRejected() {
        #expect(!ServerURLValidator.isAcceptable(url("ftp://localhost"), allowInsecureLocal: true))
        #expect(!ServerURLValidator.isAcceptable(url("https:///"), allowInsecureLocal: true))
    }

    @Test func isLocalHostRecognizesLocalForms() {
        #expect(ServerURLValidator.isLocalHost("localhost"))
        #expect(ServerURLValidator.isLocalHost("My-Mac.local"))
        #expect(ServerURLValidator.isLocalHost("127.0.0.1"))
        #expect(ServerURLValidator.isLocalHost("devbox"))      // bare, dot-less
        #expect(!ServerURLValidator.isLocalHost("example.com"))
        #expect(!ServerURLValidator.isLocalHost("slipstream.atassi.org"))
    }

    @Test func debugBuildAllowsInsecureLocal() {
        // Tests build in Debug; this guards the compile flag's Debug branch.
        #expect(DevSupport.allowsInsecureLocalServers)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/SlipStreamKit --filter ServerURLValidatorTests`
Expected: FAIL — `cannot find 'ServerURLValidator' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/ServerURLValidator.swift`:

```swift
import Foundation

/// Compile-time posture for insecure local servers. Debug builds may talk plain HTTP to
/// local hosts (paired with the Debug-only `NSAllowsLocalNetworking` ATS exception);
/// Release stays strictly HTTPS, so shipping builds are unchanged.
public enum DevSupport {
    public static var allowsInsecureLocalServers: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}

/// Validates a user-entered server origin before sign-in.
///
/// HTTPS is always acceptable. Plain HTTP is acceptable only to local hosts and only when
/// `allowInsecureLocal` is true — this mirrors exactly what `NSAllowsLocalNetworking`
/// permits at the network layer, so the Sign-In button never enables a request that ATS
/// would then reject.
public enum ServerURLValidator {
    public static func isAcceptable(_ url: URL, allowInsecureLocal: Bool) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              let host = url.host, !host.isEmpty else { return false }
        switch scheme {
        case "https": return true
        case "http": return allowInsecureLocal && isLocalHost(host)
        default: return false
        }
    }

    /// Hosts reachable over plain HTTP under `NSAllowsLocalNetworking`:
    /// loopback, Bonjour `.local` names, and bare (dot-less) hostnames.
    public static func isLocalHost(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == "localhost"
            || h == "127.0.0.1"
            || h == "::1"
            || h.hasSuffix(".local")
            || !h.contains(".")
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages/SlipStreamKit --filter ServerURLValidatorTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/ServerURLValidator.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/ServerURLValidatorTests.swift
git commit -m "feat: add ServerURLValidator + Debug insecure-local posture"
```

---

### Task 3: `DevServerPreset`

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/DevServerPreset.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/DevServerPresetTests.swift`

**Interfaces:**
- Consumes: `DevLaunchConfig` (Task 1).
- Produces: `DevServerPreset(id:name:urlString:)`; `.localhost`, `.production`, `.macOnLAN(from:)`, `.all(config:)`.

- [ ] **Step 1: Write the failing test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/DevServerPresetTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct DevServerPresetTests {
    @Test func localhostPresetTargetsLoopbackDevPort() {
        #expect(DevServerPreset.localhost.urlString == "http://localhost:8080")
        let host = URL(string: DevServerPreset.localhost.urlString)!.host!
        #expect(ServerURLValidator.isLocalHost(host))
    }

    @Test func productionPresetIsHTTPS() {
        #expect(DevServerPreset.production.urlString == "https://slipstream.atassi.org")
    }

    @Test func macOnLANUsesDotLocalOverrideWhenPresent() {
        let cfg = DevLaunchConfig(environment: ["SLIPSTREAM_BASE_URL": "http://jacks-mac.local:8080"])
        #expect(DevServerPreset.macOnLAN(from: cfg).urlString == "http://jacks-mac.local:8080")
    }

    @Test func macOnLANFallsBackToEditablePlaceholderOtherwise() {
        let cfg = DevLaunchConfig(environment: [:])
        #expect(DevServerPreset.macOnLAN(from: cfg).urlString == "http://your-mac.local:8080")
        // A non-.local override (e.g. localhost) does not hijack the LAN preset.
        let local = DevLaunchConfig(environment: ["SLIPSTREAM_BASE_URL": "http://localhost:8080"])
        #expect(DevServerPreset.macOnLAN(from: local).urlString == "http://your-mac.local:8080")
    }

    @Test func allListsThreePresetsInOrder() {
        let presets = DevServerPreset.all(config: DevLaunchConfig(environment: [:]))
        #expect(presets.map(\.id) == ["localhost", "lan", "production"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/SlipStreamKit --filter DevServerPresetTests`
Expected: FAIL — `cannot find 'DevServerPreset' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/DevServerPreset.swift`:

```swift
import Foundation

/// A named, one-tap server target surfaced in the Debug sign-in picker.
public struct DevServerPreset: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let urlString: String

    public init(id: String, name: String, urlString: String) {
        self.id = id
        self.name = name
        self.urlString = urlString
    }

    /// Simulator and Mac (Designed for iPad) reach the dev server over loopback.
    public static let localhost = DevServerPreset(
        id: "localhost", name: "Localhost (sim/Mac)", urlString: "http://localhost:8080")

    /// The real server.
    public static let production = DevServerPreset(
        id: "production", name: "Production", urlString: "https://slipstream.atassi.org")

    /// "Mac on LAN" target for a physical device. A phone cannot reach `localhost`, so it
    /// addresses the Mac by its Bonjour `.local` name (stable across DHCP, and covered by
    /// `NSAllowsLocalNetworking`). Uses the `SLIPSTREAM_BASE_URL` launch override when that
    /// points at a `.local` host; otherwise an obviously-editable placeholder the tester
    /// replaces with their Mac's name.
    public static func macOnLAN(from config: DevLaunchConfig) -> DevServerPreset {
        let urlString: String
        if let override = config.baseURLOverride, override.host?.hasSuffix(".local") == true {
            urlString = override.absoluteString
        } else {
            urlString = "http://your-mac.local:8080"
        }
        return DevServerPreset(id: "lan", name: "Mac on LAN (device)", urlString: urlString)
    }

    /// All presets, in display order.
    public static func all(config: DevLaunchConfig) -> [DevServerPreset] {
        [.localhost, macOnLAN(from: config), .production]
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages/SlipStreamKit --filter DevServerPresetTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Run the full package suite (no regressions)**

Run: `swift test --package-path Packages/SlipStreamKit`
Expected: PASS — the prior 18 tests plus the 14 new ones.

- [ ] **Step 6: Commit**

```bash
git add Packages/SlipStreamKit/Sources/SlipStreamKit/Dev/DevServerPreset.swift \
        Packages/SlipStreamKit/Tests/SlipStreamKitTests/DevServerPresetTests.swift
git commit -m "feat: add DevServerPreset list for the sign-in dev picker"
```

---

### Task 4: Debug-only ATS exception (partial Info.plist)

**Files:**
- Create: `App/SlipStream-Debug-Info.plist`
- Modify: `SlipStream.xcodeproj/project.pbxproj` (Debug config block `…0111…`, `name = Debug`, after line 273)

**Interfaces:**
- Consumes: nothing.
- Produces: a Debug binary whose `Info.plist` contains `NSAppTransportSecurity → NSAllowsLocalNetworking = true`; Release unchanged.

> **Why a partial plist:** the target uses `GENERATE_INFOPLIST_FILE = YES`, and `NSAppTransportSecurity` is a nested dictionary that flat `INFOPLIST_KEY_*` settings can't express. With `GENERATE_INFOPLIST_FILE = YES` *and* `INFOPLIST_FILE` set, Xcode uses the file as the base and merges the generated keys on top. Setting `INFOPLIST_FILE` only in the Debug config means Release keeps the pure generated plist (no exception). `NSAllowsLocalNetworking` relaxes ATS *only* for loopback / `.local` / link-local hosts — public HTTPS still works and arbitrary internet HTTP stays blocked even in Debug.

- [ ] **Step 1: Create the partial Info.plist**

Create `App/SlipStream-Debug-Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
	<key>NSLocalNetworkUsageDescription</key>
	<string>Connect to a SlipStream dev server running on your Mac for local testing.</string>
</dict>
</plist>
```

- [ ] **Step 2: Point the Debug config at the partial plist**

In `SlipStream.xcodeproj/project.pbxproj`, in the block for the app target's Debug configuration (the `XCBuildConfiguration` whose id ends `…0111…` and whose `name = Debug`, lines 265–303), add one line immediately after the `GENERATE_INFOPLIST_FILE = YES;` line (line 273):

```
				INFOPLIST_FILE = "App/SlipStream-Debug-Info.plist";
```

Do **not** add it to the Release block (`…0112…`, lines 304–342). Settings are alphabetized; placing it right after `GENERATE_INFOPLIST_FILE` keeps order.

- [ ] **Step 3: Build Debug and verify the merge**

Build the app for the simulator in Debug via XcodeBuildMCP (`build_sim`, scheme `SlipStream`, configuration `Debug`, simulator `iPhone 17`). Then locate the built app and inspect its Info.plist:

Get the built app path from XcodeBuildMCP `get_sim_app_path` (scheme `SlipStream`, Debug, iOS simulator). Then, with `APP` set to that path:

```bash
# If you have the path from get_sim_app_path, set it directly; otherwise locate it:
APP=$(find ~/Library/Developer/Xcode/DerivedData -path '*Debug-iphonesimulator*/SlipStream.app' -maxdepth 8 2>/dev/null | head -1)
echo "App: $APP"
plutil -extract NSAppTransportSecurity xml1 -o - "$APP/Info.plist"
plutil -extract NSFaceIDUsageDescription raw -o - "$APP/Info.plist"
```

Expected: the first command prints a dict containing `NSAllowsLocalNetworking = true`; the second prints `Unlock SlipStream with Face ID` — proving the generated keys **merged** with the partial plist rather than replacing it.

> If `NSFaceIDUsageDescription` is missing, this Xcode treats `INFOPLIST_FILE` as a full replacement rather than a merge base. Fallback: copy the four generated `INFOPLIST_KEY_*`-equivalent keys into `App/SlipStream-Debug-Info.plist` (FaceID usage, scene manifest, supported orientations, status bar style) so the Debug plist is complete. Re-run this step.

- [ ] **Step 4: Build Release and verify the exception is absent**

Build for the simulator in Release (`build_sim`, configuration `Release`). Then:

```bash
APPR=$(find ~/Library/Developer/Xcode/DerivedData -path '*Release-iphonesimulator*/SlipStream.app' -maxdepth 8 2>/dev/null | head -1)
plutil -extract NSAppTransportSecurity xml1 -o - "$APPR/Info.plist" 2>&1 || echo "ATS key absent (expected)"
```

Expected: `NSAppTransportSecurity` is **absent** (the `plutil` extract fails / prints "ATS key absent"). This proves Release stays strict.

- [ ] **Step 5: Commit**

```bash
git add App/SlipStream-Debug-Info.plist SlipStream.xcodeproj/project.pbxproj
git commit -m "feat: Debug-only ATS NSAllowsLocalNetworking exception"
```

---

### Task 5: Validator-backed sign-in (Release becomes HTTPS-strict)

**Files:**
- Modify: `Packages/Feature-Auth/Sources/FeatureAuth/SignInView.swift:51-56` (`canSubmit`)

**Interfaces:**
- Consumes: `ServerURLValidator.isAcceptable(_:allowInsecureLocal:)`, `DevSupport.allowsInsecureLocalServers` (Task 2).
- Produces: nothing new.

> `canSubmit` currently uses `url.scheme?.hasPrefix("http")`, which accepts plain `http://` to **any** host in every configuration. Routing it through the validator makes Release strictly HTTPS while Debug allows HTTP to local hosts — aligning the button with what ATS actually permits.

- [ ] **Step 1: Replace `canSubmit`**

In `Packages/Feature-Auth/Sources/FeatureAuth/SignInView.swift`, replace the `canSubmit` computed property (currently lines 51–56):

```swift
  private var canSubmit: Bool {
    guard let url = URL(string: serverURLString) else { return false }
    guard ServerURLValidator.isAcceptable(url, allowInsecureLocal: DevSupport.allowsInsecureLocalServers)
    else { return false }
    return !username.isEmpty && pin.count == 4
  }
```

The exact current text to replace is:

```swift
  private var canSubmit: Bool {
    guard let url = URL(string: serverURLString), url.scheme?.hasPrefix("http") == true else {
      return false
    }
    return !username.isEmpty && pin.count == 4
  }
```

Then run `make format` to normalize, and `make lint`.

- [ ] **Step 2: Build the app to verify it compiles**

Build via XcodeBuildMCP (`build_sim`, scheme `SlipStream`, simulator `iPhone 17`).
Expected: BUILD SUCCEEDED. (`SignInView` already `import SlipStreamKit`, so the validator is in scope.)

- [ ] **Step 3: Commit**

```bash
git add Packages/Feature-Auth/Sources/FeatureAuth/SignInView.swift
git commit -m "refactor: validate sign-in URL via ServerURLValidator (Release HTTPS-only)"
```

---

### Task 6: Debug sign-in dev picker, credential pre-fill, launch-URL override

**Files:**
- Modify: `Packages/Feature-Auth/Sources/FeatureAuth/SignInView.swift` (Server section + `onAppear` + new Debug helpers)

**Interfaces:**
- Consumes: `DevServerPreset.all(config:)`, `DevLaunchConfig.current`, `ServerURLValidator` (Tasks 1–3).
- Produces: nothing new (UI wiring).

> Everything here is `#if DEBUG`. Release sign-in is unchanged: no picker, no pre-fill, and the original `onAppear` behavior (fill from the persisted server URL) is preserved.

- [ ] **Step 1: Add the Debug picker to the Server section**

In `SignInView.swift`, replace the `Section("Server") { … }` block (currently lines 15–21) — add the `#if DEBUG` menu before the section's closing brace:

```swift
      Section("Server") {
        TextField("https://slipstream.example.com", text: $serverURLString)
          .textContentType(.URL)
          .keyboardType(.URL)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
        #if DEBUG
          Menu("Dev Servers") {
            ForEach(DevServerPreset.all(config: .current)) { preset in
              Button(preset.name) { applyPreset(preset) }
            }
          }
        #endif
      }
```

- [ ] **Step 2: Replace `onAppear` to honor launch overrides (Debug) then persisted URL**

Replace the `.onAppear { … }` modifier (currently lines 44–48) with:

```swift
    .onAppear {
      #if DEBUG
        let cfg = DevLaunchConfig.current
        if serverURLString.isEmpty, let override = cfg.baseURLOverride {
          serverURLString = override.absoluteString
        }
        if username.isEmpty, let u = cfg.devUsername { username = u }
        if pin.isEmpty, let p = cfg.devPIN { pin = p }
      #endif
      if serverURLString.isEmpty, let existing = auth.serverBaseURLString {
        serverURLString = existing
      }
    }
```

The exact current text to replace is:

```swift
    .onAppear {
      if serverURLString.isEmpty, let existing = auth.serverBaseURLString {
        serverURLString = existing
      }
    }
```

- [ ] **Step 3: Add the Debug helpers**

Add these inside `SignInView`, immediately after the `submit()` method (currently ends line 65):

```swift
  #if DEBUG
    /// Fill the server field from a preset and, for a local dev target, pre-fill the
    /// throwaway test credentials (pre-fill only — the tester still taps Sign In, so the
    /// real login → JWT → Keychain path is exercised). Sourced from launch env vars, with
    /// a compile-time fallback so it works with zero scheme configuration.
    private func applyPreset(_ preset: DevServerPreset) {
      serverURLString = preset.urlString
      guard let url = URL(string: preset.urlString),
        url.scheme?.lowercased() == "http",
        let host = url.host, ServerURLValidator.isLocalHost(host)
      else { return }
      let cfg = DevLaunchConfig.current
      if username.isEmpty { username = cfg.devUsername ?? DevDefaults.username }
      if pin.isEmpty { pin = cfg.devPIN ?? DevDefaults.pin }
    }

    private enum DevDefaults {
      static let username = "tester"
      static let pin = "1234"
    }
  #endif
```

- [ ] **Step 4: Build the app**

Build via XcodeBuildMCP (`build_sim`, scheme `SlipStream`, simulator `iPhone 17`).
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Manually confirm the Debug affordances**

Run the app on the `iPhone 17` simulator (XcodeBuildMCP `build_run_sim`). On the sign-in screen, confirm:
- A **"Dev Servers"** menu appears under the server field.
- Tapping **"Localhost (sim/Mac)"** fills `http://localhost:8080` and pre-fills username `tester` / a 4-digit PIN (the Sign-In button is **not** auto-pressed).
- Tapping **"Production"** fills `https://slipstream.atassi.org` and does **not** pre-fill credentials.

(No automated UI test — this is a SwiftUI view; the underlying data/logic is covered by Tasks 1–3.)

- [ ] **Step 6: Commit**

```bash
git add Packages/Feature-Auth/Sources/FeatureAuth/SignInView.swift
git commit -m "feat: Debug sign-in dev picker + credential pre-fill + launch override"
```

---

### Task 7: Record the feature in the tracker

**Files:**
- Modify: `docs/TRACKER.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Add a tracker entry**

Add a row/line to `docs/TRACKER.md` recording this as a completed tooling/foundation feature, linking this plan. Match the surrounding format. Suggested text:

```markdown
- ✅ **Live-testing enablers** — Debug-only local dev-server support: ATS `NSAllowsLocalNetworking` exception, sign-in dev-server picker, `SLIPSTREAM_BASE_URL` / `SLIPSTREAM_DEV_USERNAME` / `SLIPSTREAM_DEV_PIN` launch overrides, dev-credential pre-fill. Release unchanged. Plan: `docs/superpowers/plans/2026-06-20-live-testing-enablers.md`.
```

(If `TRACKER.md` groups items under headings, place this under the foundations/tooling group, mirroring existing entries.)

- [ ] **Step 2: Commit**

```bash
git add docs/TRACKER.md
git commit -m "docs: track live-testing enablers feature"
```

---

## Final Verification

- [ ] `swift test --package-path Packages/SlipStreamKit` — all suites pass (18 prior + 14 new).
- [ ] `build_sim` Debug succeeds; built `Info.plist` contains `NSAllowsLocalNetworking = true` **and** `NSFaceIDUsageDescription` (merge proven).
- [ ] `build_sim` Release succeeds; built `Info.plist` has **no** `NSAppTransportSecurity`.
- [ ] Manual: Dev Servers picker present in Debug, fills URL + pre-fills local creds, does not auto-submit.
- [ ] Run `/code-review` before merging (CLAUDE.md: non-`docs/` change), then squash-merge to `main`.

## Notes for the follow-on skill

The skill authored next is the *operational* layer over these enablers. Its preconditions check can assert: `App/SlipStream-Debug-Info.plist` exists, the Debug `INFOPLIST_FILE` setting is present, and `DevLaunchConfig`/`DevServerPreset` exist in `SlipStreamKit/Dev/`. Its per-session ritual drives: start server (`make dev`), enable server dev mode + `external_access_enabled` (for device), build/run the app at the chosen env, smoke-verify login + a poll endpoint.
