# Codable Data Contract (F1.3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish F1.3 by hand-mirroring the rest of the SlipStream portal contract (`web/src/types/portal.ts`) into `SlipStreamKit` as Swift `Codable` types, so every later feature (requests, search, library, downloads, notifications, invitation signup) decodes the same canonical shapes — and add a self-contained drift guard so the mirror can't silently rot.

**Architecture:** Pure Foundation value types in `SlipStreamKit`, no networking or UI. Field names are mirrored verbatim (camelCase) so the synthesized `Codable` conformance matches the JSON with no `CodingKeys`. Closed server string-unions become `String`-backed Swift enums; `Record<string, unknown>` becomes a recursive `JSONValue` enum with custom `Codable`. Every type is tested headlessly with JSON fixtures via `swift test` on the Mac host — no simulator. A final task vendors a snapshot of `portal.ts` and a test that fails if the snapshot grows a type name that is neither mirrored nor explicitly excluded.

**Tech Stack:** Swift 6 (strict concurrency), Foundation `Codable`, Swift Testing (`@Suite`/`@Test`/`#expect`), Swift Package Manager. Build/test loop: `cd Packages/SlipStreamKit && swift test`.

## Global Constraints

- **Language/mode:** Swift 6, strict concurrency. Every model type must be `Codable, Equatable, Sendable`; types with a natural `id` are also `Identifiable`.
- **Contract source of truth:** `~/Git/SlipStream/web/src/types/portal.ts` (canonical), cross-checked against the Go handlers in `~/Git/SlipStream/internal/portal/requests/`. **Mirror field names verbatim (camelCase). Do not invent endpoints or fields.**
- **Timestamps:** every timestamp field (`createdAt`, `updatedAt`, `airDate`, `addedAt`, `approvedAt`, `expiresAt`, …) is typed `string` in the contract — model as Swift `String` (or `String?` where nullable). **No date parsing in v1.**
- **Optionality:** TS `field?: T` (optional property) and `field: T | null` (nullable) both map to Swift `T?`. Synthesized `Codable` decodes an absent key *or* an explicit `null` to `nil`, and encodes `nil` by omitting the key (`encodeIfPresent`) — which matches the TS `?:` semantics.
- **Numeric types (authoritative, from the Go server, not guessed):** `PortalDownload.progress` is `float64` → `Double`; `size`, `downloadedSize`, `downloadSpeed`, `eta` are `int64` → `Int`. `EnrichedEpisode.imdbRating` is a rating → `Double?`. All other `number` fields are integer ids/counts → `Int`.
- **Public API:** all types live in `public` declarations with explicit `public init(...)` memberwise initializers (a public struct does not get a public memberwise init for free, and tests + feature packages construct these across the module boundary).
- **Excluded (admin / deferred — a portal token can't reach the endpoints they serve):** `ApproveRequestInput`, `DenyRequestInput`, `BatchApproveInput`, `BatchDenyInput`, `AdminUpdateUserInput`, `CreateInvitationRequest`, `Invitation`, `InvitationModuleSetting`, `RequestSettings`, `QuotaStatus`, `ModuleQuotaStatus`, `PortalUserWithQuota`.
- **Excluded (cut feature):** the **inbox** types (`PortalNotification` and the inbox list/count responses) are defined in `web/src/api/portal/inbox.ts`, **not** in `portal.ts`, and feed F6.1/F6.2, which are **cut from v1** (TRACKER scope decision #3). They are out of scope for F1.3. The *notifier delivery-channel* types `UserNotification` / `CreateUserNotificationInput` (which live in `portal.ts` and feed the v1 features F6.3/F6.4) **are** in scope.
- **Excluded (belongs to F6.4):** `NotifierSchema` is imported by `notifications.ts` but is **not** defined in `portal.ts`; it is the schema-driven channel-editor type and will be mirrored in F6.4's own plan.
- **Commits:** one per task minimum. Solo repo; commit directly. Run `/code-review` before merging this branch to `main`; squash-merge.

---

## Already done (Plan 1 — do not recreate)

These exist in `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/` and must **not** be redefined:

- `UserModuleSetting`, `PortalUser` (`Models/PortalUser.swift`)
- `LoginRequest`, `LoginResponse` (`Models/Auth.swift`)

This plan adds everything else in `portal.ts` that a portal token can use.

## File structure (this plan)

```
Packages/SlipStreamKit/
  Package.swift                                   # Modify: add a test resource (Task 7)
  Sources/SlipStreamKit/Models/
    Enums.swift                                   # Create: RequestStatus, PortalMediaType, PortalDownloadStatus, RequestScope (Task 1)
    JSONValue.swift                               # Create: recursive JSON value for Record<string,unknown> (Task 2)
    Auth.swift                                    # Modify: + Signup/UpdateProfile/ValidateInvitation/VerifyPin (Task 3)
    Request.swift                                 # Create: Request, CreateRequestInput, RequestListFilters (Task 4)
    Search.swift                                  # Create: SlotInfo, *Availability*, *SearchResult, Enriched* (Task 5)
    Notification.swift                            # Create: UserNotification, CreateUserNotificationInput (Task 6)
    Download.swift                                # Create: PortalDownload (Task 6)
  Tests/SlipStreamKitTests/
    EnumDecodingTests.swift                       # Task 1
    JSONValueTests.swift                          # Task 2
    AuthModelTests.swift                          # Task 3
    RequestModelTests.swift                       # Task 4
    SearchModelTests.swift                        # Task 5
    NotificationDownloadModelTests.swift          # Task 6
    ContractDriftTests.swift                      # Task 7
    Contract/portal.ts                            # Task 7 (vendored snapshot, bundled as a test resource)
```

No new product dependencies. No changes outside `Packages/SlipStreamKit`.

---

### Task 1: String-union enums

The four closed string-unions from the contract, as `String`-backed enums. `RequestStatus` and `PortalMediaType` are consumed by the request and search models in later tasks; `PortalDownloadStatus` by the download model; `RequestScope` by the request-list filter. Strict (non-fallback) decoding faithfully mirrors the closed server unions.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Enums.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/EnumDecodingTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum RequestStatus: String, Codable, Equatable, Sendable, CaseIterable` — cases `pending, approved, denied, searching, downloading, failed, available, cancelled`.
  - `enum PortalMediaType: String, Codable, Equatable, Sendable, CaseIterable` — cases `movie, series, season, episode`.
  - `enum PortalDownloadStatus: String, Codable, Equatable, Sendable, CaseIterable` — cases `queued, downloading, paused, completed, failed, warning`.
  - `enum RequestScope: String, Codable, Equatable, Sendable, CaseIterable` — cases `mine, all`.

- [ ] **Step 1: Write the failing decode test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/EnumDecodingTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct EnumDecodingTests {
    @Test func requestStatusHasEightStatesInContractOrder() throws {
        let json = #"["pending","approved","denied","searching","downloading","failed","available","cancelled"]"#
        let decoded = try JSONDecoder().decode([RequestStatus].self, from: Data(json.utf8))
        #expect(decoded == RequestStatus.allCases)
        #expect(RequestStatus.allCases.count == 8)
        #expect(RequestStatus.downloading.rawValue == "downloading")
    }

    @Test func portalMediaTypeMirrorsContract() throws {
        let json = #"["movie","series","season","episode"]"#
        let decoded = try JSONDecoder().decode([PortalMediaType].self, from: Data(json.utf8))
        #expect(decoded == PortalMediaType.allCases)
    }

    @Test func portalDownloadStatusMirrorsContract() throws {
        let json = #"["queued","downloading","paused","completed","failed","warning"]"#
        let decoded = try JSONDecoder().decode([PortalDownloadStatus].self, from: Data(json.utf8))
        #expect(decoded == PortalDownloadStatus.allCases)
    }

    @Test func requestScopeMirrorsContract() throws {
        #expect(RequestScope(rawValue: "mine") == .mine)
        #expect(RequestScope(rawValue: "all") == .all)
        #expect(RequestScope(rawValue: "nope") == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'RequestStatus' in scope`.

- [ ] **Step 3: Write the enums**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Enums.swift`:

```swift
/// Mirrors `RequestStatus` in web/src/types/portal.ts (the 8-state request lifecycle).
public enum RequestStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case pending
    case approved
    case denied
    case searching
    case downloading
    case failed
    case available
    case cancelled
}

/// Mirrors `PortalMediaType` in web/src/types/portal.ts.
public enum PortalMediaType: String, Codable, Equatable, Sendable, CaseIterable {
    case movie
    case series
    case season
    case episode
}

/// Mirrors the `status` union of `PortalDownload` in web/src/types/portal.ts.
public enum PortalDownloadStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case queued
    case downloading
    case paused
    case completed
    case failed
    case warning
}

/// Mirrors the `scope` union of `RequestListFilters` in web/src/types/portal.ts.
public enum RequestScope: String, Codable, Equatable, Sendable, CaseIterable {
    case mine
    case all
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (existing 11 + 4 new).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add portal contract string-union enums"
```

---

### Task 2: JSONValue (Record<string, unknown>)

A recursive JSON value type so `UserNotification.settings` / `CreateUserNotificationInput.settings` (TS `Record<string, unknown>`) round-trip losslessly without a fixed schema. This is the only contract type that needs hand-written `Codable`.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/JSONValue.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/JSONValueTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum JSONValue: Codable, Equatable, Sendable` with cases `.string(String)`, `.number(Double)`, `.bool(Bool)`, `.object([String: JSONValue])`, `.array([JSONValue])`, `.null`.
  - Notifier settings are modeled downstream (Task 6) as `[String: JSONValue]`.

- [ ] **Step 1: Write the failing round-trip test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/JSONValueTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct JSONValueTests {
    @Test func decodesEveryScalarAndNestedShape() throws {
        let json = """
        {
          "webhookUrl": "https://hooks.example.com/abc",
          "port": 8080,
          "secure": true,
          "retries": null,
          "channels": ["general", "alerts"],
          "headers": { "X-Token": "t", "count": 3 }
        }
        """
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: Data(json.utf8))
        #expect(decoded["webhookUrl"] == .string("https://hooks.example.com/abc"))
        #expect(decoded["port"] == .number(8080))
        #expect(decoded["secure"] == .bool(true))
        #expect(decoded["retries"] == .null)
        #expect(decoded["channels"] == .array([.string("general"), .string("alerts")]))
        #expect(decoded["headers"] == .object(["X-Token": .string("t"), "count": .number(3)]))
    }

    @Test func roundTripsThroughEncodeAndDecode() throws {
        let original: JSONValue = .object([
            "a": .array([.number(1), .bool(false), .null]),
            "b": .string("x"),
        ])
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(restored == original)
    }

    @Test func encodesNullAsJSONNull() throws {
        let data = try JSONEncoder().encode(JSONValue.null)
        #expect(String(data: data, encoding: .utf8) == "null")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'JSONValue' in scope`.

- [ ] **Step 3: Write JSONValue**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/JSONValue.swift`:

```swift
import Foundation

/// A decoded JSON value of unknown shape. Mirrors TypeScript's `unknown` inside
/// `Record<string, unknown>` (e.g. `UserNotification.settings`), so notifier
/// settings round-trip losslessly without a fixed schema.
public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            // Bool must be tried before Double: JSON `true`/`false` are not numbers.
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported JSON value"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (3 new).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add JSONValue for schemaless notifier settings"
```

---

### Task 3: Auth model additions

The remaining auth/onboarding request & response types from `portal.ts`: signup (invitation redemption), profile edit, invitation validation, and PIN verification. Appended to the existing `Auth.swift`; the admin-only `CreateInvitationRequest`/`Invitation` types stay excluded.

**Files:**
- Modify: `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Auth.swift` (append; leave `LoginRequest`/`LoginResponse` untouched)
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/AuthModelTests.swift`

**Interfaces:**
- Consumes: `PortalUser` (Plan 1).
- Produces:
  - `SignupRequest(token:password:)` — `{ token: String, password: String }`.
  - `SignupResponse{ token: String, user: PortalUser }`.
  - `UpdateProfileRequest(username:password:)` — both `String?`.
  - `ValidateInvitationResponse{ valid: Bool, username: String, expiresAt: String }`.
  - `VerifyPinResponse{ valid: Bool }`.

- [ ] **Step 1: Write the failing test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/AuthModelTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct AuthModelTests {
    @Test func decodesSignupResponse() throws {
        let json = """
        {
          "token": "jwt.signed",
          "user": {
            "id": 2, "username": "newbie", "moduleSettings": [],
            "autoApprove": false, "enabled": true, "isAdmin": false,
            "createdAt": "t", "updatedAt": "t"
          }
        }
        """
        let resp = try JSONDecoder().decode(SignupResponse.self, from: Data(json.utf8))
        #expect(resp.token == "jwt.signed")
        #expect(resp.user.username == "newbie")
    }

    @Test func encodesSignupRequestVerbatim() throws {
        let data = try JSONEncoder().encode(SignupRequest(token: "inv-123", password: "4321"))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(obj?["token"] == "inv-123")
        #expect(obj?["password"] == "4321")
    }

    @Test func updateProfileOmitsNilFields() throws {
        let data = try JSONEncoder().encode(UpdateProfileRequest(username: "renamed", password: nil))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(obj?["username"] == "renamed")
        #expect(obj?.keys.contains("password") == false)
    }

    @Test func decodesValidateInvitationAndVerifyPin() throws {
        let inv = try JSONDecoder().decode(
            ValidateInvitationResponse.self,
            from: Data(#"{"valid":true,"username":"guest","expiresAt":"2026-12-31T00:00:00Z"}"#.utf8)
        )
        #expect(inv.valid == true)
        #expect(inv.username == "guest")
        #expect(inv.expiresAt == "2026-12-31T00:00:00Z")

        let pin = try JSONDecoder().decode(VerifyPinResponse.self, from: Data(#"{"valid":false}"#.utf8))
        #expect(pin.valid == false)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'SignupResponse' in scope`.

- [ ] **Step 3: Append the models**

Append to `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Auth.swift` (after the existing `LoginResponse`):

```swift
/// Mirrors `SignupRequest` in web/src/types/portal.ts. Redeems an invitation;
/// `token` is the invitation token and `password` carries the new 4-digit PIN.
public struct SignupRequest: Codable, Equatable, Sendable {
    public let token: String
    public let password: String

    public init(token: String, password: String) {
        self.token = token
        self.password = password
    }
}

/// Mirrors `SignupResponse` in web/src/types/portal.ts.
public struct SignupResponse: Codable, Equatable, Sendable {
    public let token: String
    public let user: PortalUser

    public init(token: String, user: PortalUser) {
        self.token = token
        self.user = user
    }
}

/// Mirrors `UpdateProfileRequest` in web/src/types/portal.ts. Both fields are
/// optional; `password` carries a new 4-digit PIN when changing it.
public struct UpdateProfileRequest: Codable, Equatable, Sendable {
    public let username: String?
    public let password: String?

    public init(username: String? = nil, password: String? = nil) {
        self.username = username
        self.password = password
    }
}

/// Mirrors `ValidateInvitationResponse` in web/src/types/portal.ts.
public struct ValidateInvitationResponse: Codable, Equatable, Sendable {
    public let valid: Bool
    public let username: String
    public let expiresAt: String

    public init(valid: Bool, username: String, expiresAt: String) {
        self.valid = valid
        self.username = username
        self.expiresAt = expiresAt
    }
}

/// Mirrors `VerifyPinResponse` in web/src/types/portal.ts.
public struct VerifyPinResponse: Codable, Equatable, Sendable {
    public let valid: Bool

    public init(valid: Bool) {
        self.valid = valid
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (4 new).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add signup, profile-edit, and invitation/PIN auth models"
```

---

### Task 4: Request models

`Request` (the 8-state request record), plus the `CreateRequestInput` body and `RequestListFilters` query model. Consumes the enums from Task 1.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Request.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/RequestModelTests.swift`

**Interfaces:**
- Consumes: `RequestStatus`, `PortalMediaType`, `RequestScope` (Task 1), `PortalUser` (Plan 1).
- Produces:
  - `Request` — `Codable, Equatable, Sendable, Identifiable`; fields exactly: `id: Int, userId: Int, mediaType: PortalMediaType, tmdbId: Int?, tvdbId: Int?, title: String, year: Int?, seasonNumber: Int?, episodeNumber: Int?, status: RequestStatus, monitorFuture: Bool, deniedReason: String?, approvedAt: String?, approvedBy: Int?, mediaId: Int?, targetSlotId: Int?, posterUrl: String?, requestedSeasons: [Int], createdAt: String, updatedAt: String, user: PortalUser?, isWatching: Bool?`.
  - `CreateRequestInput` — `mediaType: PortalMediaType, tmdbId: Int?, tvdbId: Int?, title: String, year: Int?, seasonNumber: Int?, episodeNumber: Int?, monitorFuture: Bool?, posterUrl: String?, requestedSeasons: [Int]?`.
  - `RequestListFilters` — `status: RequestStatus?, mediaType: PortalMediaType?, userId: Int?, scope: RequestScope?`.

- [ ] **Step 1: Write the failing test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/RequestModelTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct RequestModelTests {
    @Test func decodesFullSeriesRequestWithNestedUser() throws {
        let json = """
        {
          "id": 42, "userId": 7, "mediaType": "series",
          "tmdbId": 1399, "tvdbId": 121361, "title": "Game of Thrones",
          "year": 2011, "seasonNumber": null, "episodeNumber": null,
          "status": "downloading", "monitorFuture": true,
          "deniedReason": null, "approvedAt": "2026-01-02T00:00:00Z", "approvedBy": 1,
          "mediaId": 555, "targetSlotId": 2, "posterUrl": "https://img/poster.jpg",
          "requestedSeasons": [1, 2, 3],
          "createdAt": "2026-01-01T00:00:00Z", "updatedAt": "2026-01-02T00:00:00Z",
          "user": {
            "id": 7, "username": "jack", "moduleSettings": [],
            "autoApprove": true, "enabled": true, "isAdmin": false,
            "createdAt": "t", "updatedAt": "t"
          },
          "isWatching": true
        }
        """
        let req = try JSONDecoder().decode(Request.self, from: Data(json.utf8))
        #expect(req.id == 42)
        #expect(req.mediaType == .series)
        #expect(req.status == .downloading)
        #expect(req.tvdbId == 121361)
        #expect(req.seasonNumber == nil)
        #expect(req.monitorFuture == true)
        #expect(req.requestedSeasons == [1, 2, 3])
        #expect(req.user?.username == "jack")
        #expect(req.isWatching == true)
    }

    @Test func decodesMinimalRequestWithAbsentOptionalUserAndWatch() throws {
        let json = """
        {
          "id": 1, "userId": 7, "mediaType": "movie",
          "tmdbId": 603, "tvdbId": null, "title": "The Matrix",
          "year": 1999, "seasonNumber": null, "episodeNumber": null,
          "status": "pending", "monitorFuture": false,
          "deniedReason": null, "approvedAt": null, "approvedBy": null,
          "mediaId": null, "targetSlotId": null, "posterUrl": null,
          "requestedSeasons": [],
          "createdAt": "t", "updatedAt": "t"
        }
        """
        let req = try JSONDecoder().decode(Request.self, from: Data(json.utf8))
        #expect(req.mediaType == .movie)
        #expect(req.status == .pending)
        #expect(req.user == nil)
        #expect(req.isWatching == nil)
        #expect(req.requestedSeasons.isEmpty)
    }

    @Test func createRequestInputOmitsNilOptionalFields() throws {
        let input = CreateRequestInput(
            mediaType: .movie, tmdbId: 603, tvdbId: nil, title: "The Matrix",
            year: 1999, seasonNumber: nil, episodeNumber: nil,
            monitorFuture: nil, posterUrl: nil, requestedSeasons: nil
        )
        let obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(input)) as? [String: Any]
        #expect(obj?["mediaType"] as? String == "movie")
        #expect(obj?["tmdbId"] as? Int == 603)
        #expect(obj?.keys.contains("tvdbId") == false)
        #expect(obj?.keys.contains("seasonNumber") == false)
        #expect(obj?.keys.contains("monitorFuture") == false)
    }

    @Test func requestListFiltersHoldEnumValues() {
        let filters = RequestListFilters(status: .available, mediaType: .series, userId: 7, scope: .mine)
        #expect(filters.status == .available)
        #expect(filters.scope == .mine)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'Request' in scope`.

- [ ] **Step 3: Write the models**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Request.swift`:

```swift
import Foundation

/// Mirrors `Request` in web/src/types/portal.ts (a portal request record).
public struct Request: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let userId: Int
    public let mediaType: PortalMediaType
    public let tmdbId: Int?
    public let tvdbId: Int?
    public let title: String
    public let year: Int?
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let status: RequestStatus
    public let monitorFuture: Bool
    public let deniedReason: String?
    public let approvedAt: String?
    public let approvedBy: Int?
    public let mediaId: Int?
    public let targetSlotId: Int?
    public let posterUrl: String?
    public let requestedSeasons: [Int]
    public let createdAt: String
    public let updatedAt: String
    public let user: PortalUser?
    public let isWatching: Bool?

    public init(
        id: Int,
        userId: Int,
        mediaType: PortalMediaType,
        tmdbId: Int?,
        tvdbId: Int?,
        title: String,
        year: Int?,
        seasonNumber: Int?,
        episodeNumber: Int?,
        status: RequestStatus,
        monitorFuture: Bool,
        deniedReason: String?,
        approvedAt: String?,
        approvedBy: Int?,
        mediaId: Int?,
        targetSlotId: Int?,
        posterUrl: String?,
        requestedSeasons: [Int],
        createdAt: String,
        updatedAt: String,
        user: PortalUser? = nil,
        isWatching: Bool? = nil
    ) {
        self.id = id
        self.userId = userId
        self.mediaType = mediaType
        self.tmdbId = tmdbId
        self.tvdbId = tvdbId
        self.title = title
        self.year = year
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.status = status
        self.monitorFuture = monitorFuture
        self.deniedReason = deniedReason
        self.approvedAt = approvedAt
        self.approvedBy = approvedBy
        self.mediaId = mediaId
        self.targetSlotId = targetSlotId
        self.posterUrl = posterUrl
        self.requestedSeasons = requestedSeasons
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.user = user
        self.isWatching = isWatching
    }
}

/// Mirrors `CreateRequestInput` in web/src/types/portal.ts (the create-request body).
public struct CreateRequestInput: Codable, Equatable, Sendable {
    public let mediaType: PortalMediaType
    public let tmdbId: Int?
    public let tvdbId: Int?
    public let title: String
    public let year: Int?
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let monitorFuture: Bool?
    public let posterUrl: String?
    public let requestedSeasons: [Int]?

    public init(
        mediaType: PortalMediaType,
        tmdbId: Int? = nil,
        tvdbId: Int? = nil,
        title: String,
        year: Int? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        monitorFuture: Bool? = nil,
        posterUrl: String? = nil,
        requestedSeasons: [Int]? = nil
    ) {
        self.mediaType = mediaType
        self.tmdbId = tmdbId
        self.tvdbId = tvdbId
        self.title = title
        self.year = year
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.monitorFuture = monitorFuture
        self.posterUrl = posterUrl
        self.requestedSeasons = requestedSeasons
    }
}

/// Mirrors `RequestListFilters` in web/src/types/portal.ts (the request-list query params).
public struct RequestListFilters: Codable, Equatable, Sendable {
    public let status: RequestStatus?
    public let mediaType: PortalMediaType?
    public let userId: Int?
    public let scope: RequestScope?

    public init(
        status: RequestStatus? = nil,
        mediaType: PortalMediaType? = nil,
        userId: Int? = nil,
        scope: RequestScope? = nil
    ) {
        self.status = status
        self.mediaType = mediaType
        self.userId = userId
        self.scope = scope
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (4 new).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add Request, CreateRequestInput, and RequestListFilters"
```

---

### Task 5: Search & availability models

The search-with-availability surface: `SlotInfo`, `SeasonAvailabilityInfo`, `AvailabilityInfo`, the two `*SearchResult` types, and the enriched season/episode breakdown.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Search.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/SearchModelTests.swift`

**Interfaces:**
- Consumes: `RequestStatus` (Task 1).
- Produces:
  - `SlotInfo` — `Codable, Equatable, Sendable, Identifiable`; `id: Int, name: String, quality: String`.
  - `SeasonAvailabilityInfo` — `seasonNumber: Int, available: Bool, hasAnyFiles: Bool, airedEpisodesWithFiles: Int, totalAiredEpisodes: Int, totalEpisodes: Int, monitored: Bool`.
  - `AvailabilityInfo` — `inLibrary: Bool, existingSlots: [SlotInfo], canRequest: Bool, existingRequestId: Int?, existingRequestUserId: Int?, existingRequestStatus: RequestStatus?, existingRequestIsWatching: Bool?, mediaId: Int?, addedAt: String?, seasonAvailability: [SeasonAvailabilityInfo]?`.
  - `PortalMovieSearchResult` — `Identifiable`; `id: Int, tmdbId: Int, title: String, year: Int?, overview: String?, posterUrl: String?, backdropUrl: String?, availability: AvailabilityInfo?`.
  - `PortalSeriesSearchResult` — `Identifiable`; `id: Int, tmdbId: Int, tvdbId: Int?, title: String, year: Int?, overview: String?, posterUrl: String?, backdropUrl: String?, network: String?, networkLogoUrl: String?, availability: AvailabilityInfo?`.
  - `EnrichedEpisode` — `episodeNumber: Int, seasonNumber: Int, title: String, overview: String?, airDate: String?, runtime: Int?, imdbRating: Double?, hasFile: Bool, monitored: Bool, aired: Bool`.
  - `EnrichedSeason` — `seasonNumber: Int, name: String, overview: String?, posterUrl: String?, airDate: String?, episodes: [EnrichedEpisode]?, inLibrary: Bool, available: Bool, monitored: Bool, airedEpisodesWithFiles: Int, totalAiredEpisodes: Int, episodeCount: Int, existingRequestId: Int?, existingRequestUserId: Int?, existingRequestStatus: RequestStatus?, existingRequestIsWatching: Bool?`.

- [ ] **Step 1: Write the failing test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/SearchModelTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct SearchModelTests {
    @Test func decodesMovieSearchResultWithAvailability() throws {
        let json = """
        {
          "id": 10, "tmdbId": 603, "title": "The Matrix", "year": 1999,
          "overview": "A hacker learns the truth.", "posterUrl": "p.jpg", "backdropUrl": null,
          "availability": {
            "inLibrary": true,
            "existingSlots": [ { "id": 1, "name": "4K", "quality": "2160p" } ],
            "canRequest": false,
            "existingRequestId": 5, "existingRequestUserId": 7,
            "existingRequestStatus": "available", "existingRequestIsWatching": false,
            "mediaId": 99, "addedAt": "2026-01-01T00:00:00Z"
          }
        }
        """
        let movie = try JSONDecoder().decode(PortalMovieSearchResult.self, from: Data(json.utf8))
        #expect(movie.tmdbId == 603)
        #expect(movie.backdropUrl == nil)
        #expect(movie.availability?.inLibrary == true)
        #expect(movie.availability?.existingSlots.first?.quality == "2160p")
        #expect(movie.availability?.existingRequestStatus == .available)
        #expect(movie.availability?.seasonAvailability == nil)
    }

    @Test func decodesSeriesSearchResultWithoutOptionalNetworkOrAvailability() throws {
        let json = """
        {
          "id": 20, "tmdbId": 1399, "tvdbId": 121361, "title": "Game of Thrones",
          "year": 2011, "overview": null, "posterUrl": null, "backdropUrl": null
        }
        """
        let series = try JSONDecoder().decode(PortalSeriesSearchResult.self, from: Data(json.utf8))
        #expect(series.tvdbId == 121361)
        #expect(series.network == nil)
        #expect(series.networkLogoUrl == nil)
        #expect(series.availability == nil)
    }

    @Test func decodesEnrichedSeasonWithEpisodes() throws {
        let json = """
        {
          "seasonNumber": 1, "name": "Season 1", "overview": "The beginning",
          "posterUrl": "s1.jpg", "airDate": "2011-04-17",
          "episodes": [
            {
              "episodeNumber": 1, "seasonNumber": 1, "title": "Winter Is Coming",
              "overview": "Ned is asked to serve.", "airDate": "2011-04-17",
              "runtime": 62, "imdbRating": 9.1, "hasFile": true, "monitored": true, "aired": true
            }
          ],
          "inLibrary": true, "available": false, "monitored": true,
          "airedEpisodesWithFiles": 10, "totalAiredEpisodes": 10, "episodeCount": 10,
          "existingRequestStatus": "downloading"
        }
        """
        let season = try JSONDecoder().decode(EnrichedSeason.self, from: Data(json.utf8))
        #expect(season.seasonNumber == 1)
        #expect(season.episodes?.count == 1)
        #expect(season.episodes?.first?.imdbRating == 9.1)
        #expect(season.episodes?.first?.runtime == 62)
        #expect(season.episodeCount == 10)
        #expect(season.existingRequestStatus == .downloading)
        #expect(season.existingRequestId == nil)
    }

    @Test func decodesSeasonAvailabilityInfo() throws {
        let json = """
        {
          "seasonNumber": 2, "available": true, "hasAnyFiles": true,
          "airedEpisodesWithFiles": 9, "totalAiredEpisodes": 10, "totalEpisodes": 10,
          "monitored": false
        }
        """
        let info = try JSONDecoder().decode(SeasonAvailabilityInfo.self, from: Data(json.utf8))
        #expect(info.available == true)
        #expect(info.airedEpisodesWithFiles == 9)
        #expect(info.monitored == false)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'PortalMovieSearchResult' in scope`.

- [ ] **Step 3: Write the models**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Search.swift`:

```swift
import Foundation

/// Mirrors `SlotInfo` in web/src/types/portal.ts.
public struct SlotInfo: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let quality: String

    public init(id: Int, name: String, quality: String) {
        self.id = id
        self.name = name
        self.quality = quality
    }
}

/// Mirrors `SeasonAvailabilityInfo` in web/src/types/portal.ts.
public struct SeasonAvailabilityInfo: Codable, Equatable, Sendable {
    public let seasonNumber: Int
    public let available: Bool
    public let hasAnyFiles: Bool
    public let airedEpisodesWithFiles: Int
    public let totalAiredEpisodes: Int
    public let totalEpisodes: Int
    public let monitored: Bool

    public init(
        seasonNumber: Int,
        available: Bool,
        hasAnyFiles: Bool,
        airedEpisodesWithFiles: Int,
        totalAiredEpisodes: Int,
        totalEpisodes: Int,
        monitored: Bool
    ) {
        self.seasonNumber = seasonNumber
        self.available = available
        self.hasAnyFiles = hasAnyFiles
        self.airedEpisodesWithFiles = airedEpisodesWithFiles
        self.totalAiredEpisodes = totalAiredEpisodes
        self.totalEpisodes = totalEpisodes
        self.monitored = monitored
    }
}

/// Mirrors `AvailabilityInfo` in web/src/types/portal.ts.
public struct AvailabilityInfo: Codable, Equatable, Sendable {
    public let inLibrary: Bool
    public let existingSlots: [SlotInfo]
    public let canRequest: Bool
    public let existingRequestId: Int?
    public let existingRequestUserId: Int?
    public let existingRequestStatus: RequestStatus?
    public let existingRequestIsWatching: Bool?
    public let mediaId: Int?
    public let addedAt: String?
    public let seasonAvailability: [SeasonAvailabilityInfo]?

    public init(
        inLibrary: Bool,
        existingSlots: [SlotInfo],
        canRequest: Bool,
        existingRequestId: Int? = nil,
        existingRequestUserId: Int? = nil,
        existingRequestStatus: RequestStatus? = nil,
        existingRequestIsWatching: Bool? = nil,
        mediaId: Int? = nil,
        addedAt: String? = nil,
        seasonAvailability: [SeasonAvailabilityInfo]? = nil
    ) {
        self.inLibrary = inLibrary
        self.existingSlots = existingSlots
        self.canRequest = canRequest
        self.existingRequestId = existingRequestId
        self.existingRequestUserId = existingRequestUserId
        self.existingRequestStatus = existingRequestStatus
        self.existingRequestIsWatching = existingRequestIsWatching
        self.mediaId = mediaId
        self.addedAt = addedAt
        self.seasonAvailability = seasonAvailability
    }
}

/// Mirrors `PortalMovieSearchResult` in web/src/types/portal.ts.
public struct PortalMovieSearchResult: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let tmdbId: Int
    public let title: String
    public let year: Int?
    public let overview: String?
    public let posterUrl: String?
    public let backdropUrl: String?
    public let availability: AvailabilityInfo?

    public init(
        id: Int,
        tmdbId: Int,
        title: String,
        year: Int? = nil,
        overview: String? = nil,
        posterUrl: String? = nil,
        backdropUrl: String? = nil,
        availability: AvailabilityInfo? = nil
    ) {
        self.id = id
        self.tmdbId = tmdbId
        self.title = title
        self.year = year
        self.overview = overview
        self.posterUrl = posterUrl
        self.backdropUrl = backdropUrl
        self.availability = availability
    }
}

/// Mirrors `PortalSeriesSearchResult` in web/src/types/portal.ts.
public struct PortalSeriesSearchResult: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let tmdbId: Int
    public let tvdbId: Int?
    public let title: String
    public let year: Int?
    public let overview: String?
    public let posterUrl: String?
    public let backdropUrl: String?
    public let network: String?
    public let networkLogoUrl: String?
    public let availability: AvailabilityInfo?

    public init(
        id: Int,
        tmdbId: Int,
        tvdbId: Int? = nil,
        title: String,
        year: Int? = nil,
        overview: String? = nil,
        posterUrl: String? = nil,
        backdropUrl: String? = nil,
        network: String? = nil,
        networkLogoUrl: String? = nil,
        availability: AvailabilityInfo? = nil
    ) {
        self.id = id
        self.tmdbId = tmdbId
        self.tvdbId = tvdbId
        self.title = title
        self.year = year
        self.overview = overview
        self.posterUrl = posterUrl
        self.backdropUrl = backdropUrl
        self.network = network
        self.networkLogoUrl = networkLogoUrl
        self.availability = availability
    }
}

/// Mirrors `EnrichedEpisode` in web/src/types/portal.ts.
public struct EnrichedEpisode: Codable, Equatable, Sendable {
    public let episodeNumber: Int
    public let seasonNumber: Int
    public let title: String
    public let overview: String?
    public let airDate: String?
    public let runtime: Int?
    public let imdbRating: Double?
    public let hasFile: Bool
    public let monitored: Bool
    public let aired: Bool

    public init(
        episodeNumber: Int,
        seasonNumber: Int,
        title: String,
        overview: String? = nil,
        airDate: String? = nil,
        runtime: Int? = nil,
        imdbRating: Double? = nil,
        hasFile: Bool,
        monitored: Bool,
        aired: Bool
    ) {
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.title = title
        self.overview = overview
        self.airDate = airDate
        self.runtime = runtime
        self.imdbRating = imdbRating
        self.hasFile = hasFile
        self.monitored = monitored
        self.aired = aired
    }
}

/// Mirrors `EnrichedSeason` in web/src/types/portal.ts.
public struct EnrichedSeason: Codable, Equatable, Sendable {
    public let seasonNumber: Int
    public let name: String
    public let overview: String?
    public let posterUrl: String?
    public let airDate: String?
    public let episodes: [EnrichedEpisode]?
    public let inLibrary: Bool
    public let available: Bool
    public let monitored: Bool
    public let airedEpisodesWithFiles: Int
    public let totalAiredEpisodes: Int
    public let episodeCount: Int
    public let existingRequestId: Int?
    public let existingRequestUserId: Int?
    public let existingRequestStatus: RequestStatus?
    public let existingRequestIsWatching: Bool?

    public init(
        seasonNumber: Int,
        name: String,
        overview: String? = nil,
        posterUrl: String? = nil,
        airDate: String? = nil,
        episodes: [EnrichedEpisode]? = nil,
        inLibrary: Bool,
        available: Bool,
        monitored: Bool,
        airedEpisodesWithFiles: Int,
        totalAiredEpisodes: Int,
        episodeCount: Int,
        existingRequestId: Int? = nil,
        existingRequestUserId: Int? = nil,
        existingRequestStatus: RequestStatus? = nil,
        existingRequestIsWatching: Bool? = nil
    ) {
        self.seasonNumber = seasonNumber
        self.name = name
        self.overview = overview
        self.posterUrl = posterUrl
        self.airDate = airDate
        self.episodes = episodes
        self.inLibrary = inLibrary
        self.available = available
        self.monitored = monitored
        self.airedEpisodesWithFiles = airedEpisodesWithFiles
        self.totalAiredEpisodes = totalAiredEpisodes
        self.episodeCount = episodeCount
        self.existingRequestId = existingRequestId
        self.existingRequestUserId = existingRequestUserId
        self.existingRequestStatus = existingRequestStatus
        self.existingRequestIsWatching = existingRequestIsWatching
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (4 new).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add search, availability, and enriched season/episode models"
```

---

### Task 6: Notification & download models

The notifier delivery-channel types (`UserNotification`, `CreateUserNotificationInput`) and the `PortalDownload` queue item. `settings` uses `[String: JSONValue]` (Task 2); `status` uses `PortalDownloadStatus` (Task 1); numeric types are the authoritative Go types.

**Files:**
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Notification.swift`
- Create: `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Download.swift`
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/NotificationDownloadModelTests.swift`

**Interfaces:**
- Consumes: `JSONValue` (Task 2), `PortalDownloadStatus` (Task 1).
- Produces:
  - `UserNotification` — `Codable, Equatable, Sendable, Identifiable`; `id: Int, userId: Int, type: String, name: String, settings: [String: JSONValue], onAvailable: Bool, onApproved: Bool, onDenied: Bool, enabled: Bool, createdAt: String, updatedAt: String`.
  - `CreateUserNotificationInput` — `type: String, name: String, settings: [String: JSONValue], onAvailable: Bool, onApproved: Bool, onDenied: Bool, enabled: Bool`.
  - `PortalDownload` — `Identifiable` with `id: String`; `clientId: Int, clientName: String, title: String, mediaType: String, status: PortalDownloadStatus, progress: Double, size: Int, downloadedSize: Int, downloadSpeed: Int, eta: Int, season: Int?, episode: Int?, movieId: Int?, seriesId: Int?, seasonNumber: Int?, isSeasonPack: Bool?, requestId: Int, requestTitle: String, requestMediaId: Int?, tmdbId: Int?, tvdbId: Int?`.

- [ ] **Step 1: Write the failing test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/NotificationDownloadModelTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

@Suite struct NotificationDownloadModelTests {
    @Test func decodesUserNotificationWithSchemalessSettings() throws {
        let json = """
        {
          "id": 3, "userId": 7, "type": "discord", "name": "My Discord",
          "settings": { "webhookUrl": "https://discord/x", "username": "bot", "retries": 5 },
          "onAvailable": true, "onApproved": false, "onDenied": true, "enabled": true,
          "createdAt": "t", "updatedAt": "t"
        }
        """
        let note = try JSONDecoder().decode(UserNotification.self, from: Data(json.utf8))
        #expect(note.id == 3)
        #expect(note.type == "discord")
        #expect(note.settings["webhookUrl"] == .string("https://discord/x"))
        #expect(note.settings["retries"] == .number(5))
        #expect(note.onAvailable == true)
        #expect(note.onApproved == false)
    }

    @Test func encodesCreateUserNotificationInputWithSettings() throws {
        let input = CreateUserNotificationInput(
            type: "webhook", name: "Hook",
            settings: ["url": .string("https://h/x"), "secure": .bool(true)],
            onAvailable: true, onApproved: true, onDenied: false, enabled: true
        )
        let obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(input)) as? [String: Any]
        #expect(obj?["type"] as? String == "webhook")
        let settings = obj?["settings"] as? [String: Any]
        #expect(settings?["url"] as? String == "https://h/x")
        #expect(settings?["secure"] as? Bool == true)
    }

    @Test func decodesPortalDownloadWithNumericTypes() throws {
        let json = """
        {
          "id": "dl-abc", "clientId": 1, "clientName": "qBittorrent",
          "title": "The.Matrix.1999.2160p", "mediaType": "movie",
          "status": "downloading", "progress": 42.5,
          "size": 80000000000, "downloadedSize": 34000000000,
          "downloadSpeed": 12500000, "eta": 3680,
          "movieId": 99, "isSeasonPack": false,
          "requestId": 5, "requestTitle": "The Matrix", "requestMediaId": 99,
          "tmdbId": 603
        }
        """
        let dl = try JSONDecoder().decode(PortalDownload.self, from: Data(json.utf8))
        #expect(dl.id == "dl-abc")
        #expect(dl.status == .downloading)
        #expect(dl.progress == 42.5)
        #expect(dl.size == 80_000_000_000)
        #expect(dl.downloadSpeed == 12_500_000)
        #expect(dl.eta == 3680)
        #expect(dl.season == nil)
        #expect(dl.movieId == 99)
        #expect(dl.requestId == 5)
        #expect(dl.tvdbId == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: compile failure — `cannot find 'UserNotification' in scope`.

- [ ] **Step 3: Write the models**

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Notification.swift`:

```swift
import Foundation

/// Mirrors `UserNotification` in web/src/types/portal.ts (a configured notifier
/// delivery channel). `settings` is schemaless (`Record<string, unknown>`).
public struct UserNotification: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let userId: Int
    public let type: String
    public let name: String
    public let settings: [String: JSONValue]
    public let onAvailable: Bool
    public let onApproved: Bool
    public let onDenied: Bool
    public let enabled: Bool
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: Int,
        userId: Int,
        type: String,
        name: String,
        settings: [String: JSONValue],
        onAvailable: Bool,
        onApproved: Bool,
        onDenied: Bool,
        enabled: Bool,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.name = name
        self.settings = settings
        self.onAvailable = onAvailable
        self.onApproved = onApproved
        self.onDenied = onDenied
        self.enabled = enabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Mirrors `CreateUserNotificationInput` in web/src/types/portal.ts (the
/// create/update body for a notifier channel).
public struct CreateUserNotificationInput: Codable, Equatable, Sendable {
    public let type: String
    public let name: String
    public let settings: [String: JSONValue]
    public let onAvailable: Bool
    public let onApproved: Bool
    public let onDenied: Bool
    public let enabled: Bool

    public init(
        type: String,
        name: String,
        settings: [String: JSONValue],
        onAvailable: Bool,
        onApproved: Bool,
        onDenied: Bool,
        enabled: Bool
    ) {
        self.type = type
        self.name = name
        self.settings = settings
        self.onAvailable = onAvailable
        self.onApproved = onApproved
        self.onDenied = onDenied
        self.enabled = enabled
    }
}
```

Create `Packages/SlipStreamKit/Sources/SlipStreamKit/Models/Download.swift`:

```swift
import Foundation

/// Mirrors `PortalDownload` in web/src/types/portal.ts (a queue item filtered to
/// the user's requests). Numeric types follow the Go server: `progress` is a
/// Double; `size`/`downloadedSize`/`downloadSpeed`/`eta` are integers.
public struct PortalDownload: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let clientId: Int
    public let clientName: String
    public let title: String
    public let mediaType: String
    public let status: PortalDownloadStatus
    public let progress: Double
    public let size: Int
    public let downloadedSize: Int
    public let downloadSpeed: Int
    public let eta: Int
    public let season: Int?
    public let episode: Int?
    public let movieId: Int?
    public let seriesId: Int?
    public let seasonNumber: Int?
    public let isSeasonPack: Bool?
    public let requestId: Int
    public let requestTitle: String
    public let requestMediaId: Int?
    public let tmdbId: Int?
    public let tvdbId: Int?

    public init(
        id: String,
        clientId: Int,
        clientName: String,
        title: String,
        mediaType: String,
        status: PortalDownloadStatus,
        progress: Double,
        size: Int,
        downloadedSize: Int,
        downloadSpeed: Int,
        eta: Int,
        season: Int? = nil,
        episode: Int? = nil,
        movieId: Int? = nil,
        seriesId: Int? = nil,
        seasonNumber: Int? = nil,
        isSeasonPack: Bool? = nil,
        requestId: Int,
        requestTitle: String,
        requestMediaId: Int? = nil,
        tmdbId: Int? = nil,
        tvdbId: Int? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.clientName = clientName
        self.title = title
        self.mediaType = mediaType
        self.status = status
        self.progress = progress
        self.size = size
        self.downloadedSize = downloadedSize
        self.downloadSpeed = downloadSpeed
        self.eta = eta
        self.season = season
        self.episode = episode
        self.movieId = movieId
        self.seriesId = seriesId
        self.seasonNumber = seasonNumber
        self.isSeasonPack = isSeasonPack
        self.requestId = requestId
        self.requestTitle = requestTitle
        self.requestMediaId = requestMediaId
        self.tmdbId = tmdbId
        self.tvdbId = tvdbId
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass (3 new).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(kit): add UserNotification, CreateUserNotificationInput, and PortalDownload"
```

---

### Task 7: Contract drift guard

A self-contained guard so the mirror can't silently rot. Vendor a snapshot of the live `portal.ts` into the test bundle, then a test parses every `export type Name` from the snapshot and asserts each is **either** mirrored in Swift **or** in an explicit excluded set with a reason. When the server contract gains a new type and someone re-vendors the snapshot, this test fails until the new type is mirrored or deliberately excluded.

The snapshot is the in-repo record of "the contract we mirrored." Refreshing it (and re-running this test) is the documented drift check against the server: `cp ~/Git/SlipStream/web/src/types/portal.ts Packages/SlipStreamKit/Tests/SlipStreamKitTests/Contract/portal.ts`.

**Files:**
- Create: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/Contract/portal.ts` (vendored snapshot)
- Modify: `Packages/SlipStreamKit/Package.swift` (bundle the snapshot as a test resource)
- Test: `Packages/SlipStreamKit/Tests/SlipStreamKitTests/ContractDriftTests.swift`

**Interfaces:**
- Consumes: nothing (reads the vendored file via `Bundle.module`).
- Produces: nothing (guard only).

- [ ] **Step 1: Vendor the current contract snapshot**

Run from the repo root:

```bash
mkdir -p Packages/SlipStreamKit/Tests/SlipStreamKitTests/Contract
cp ~/Git/SlipStream/web/src/types/portal.ts Packages/SlipStreamKit/Tests/SlipStreamKitTests/Contract/portal.ts
```

- [ ] **Step 2: Bundle the snapshot as a test resource**

Modify `Packages/SlipStreamKit/Package.swift` — change the test target to declare the resource:

```swift
        .testTarget(
            name: "SlipStreamKitTests",
            dependencies: ["SlipStreamKit"],
            resources: [.copy("Contract/portal.ts")]
        ),
```

- [ ] **Step 3: Write the failing drift test**

Create `Packages/SlipStreamKit/Tests/SlipStreamKitTests/ContractDriftTests.swift`:

```swift
import Testing
import Foundation
@testable import SlipStreamKit

/// Fails when the vendored `portal.ts` snapshot contains an `export type` that is
/// neither mirrored in Swift nor explicitly excluded — i.e. the contract drifted
/// and the Swift models (or this manifest) were not updated to match.
@Suite struct ContractDriftTests {
    /// Types mirrored into SlipStreamKit (this plan + Plan 1).
    static let mirrored: Set<String> = [
        "UserModuleSetting", "PortalUser",
        "LoginRequest", "LoginResponse",
        "SignupRequest", "SignupResponse", "UpdateProfileRequest",
        "ValidateInvitationResponse", "VerifyPinResponse",
        "RequestStatus", "PortalMediaType", "Request", "CreateRequestInput", "RequestListFilters",
        "SeasonAvailabilityInfo", "AvailabilityInfo", "SlotInfo",
        "PortalMovieSearchResult", "PortalSeriesSearchResult",
        "EnrichedEpisode", "EnrichedSeason",
        "UserNotification", "CreateUserNotificationInput",
        "PortalDownload",
    ]

    /// Deliberately NOT mirrored — admin-only, deferred, or cut features.
    /// (A portal token cannot reach the endpoints the admin types serve.)
    static let excluded: Set<String> = [
        "PortalUserWithQuota",
        "Invitation", "InvitationModuleSetting", "CreateInvitationRequest",
        "ApproveRequestInput", "DenyRequestInput", "BatchApproveInput", "BatchDenyInput",
        "ModuleQuotaStatus", "QuotaStatus",
        "RequestSettings", "AdminUpdateUserInput",
    ]

    private func vendoredTypeNames() throws -> [String] {
        let url = try #require(Bundle.module.url(forResource: "portal", withExtension: "ts"))
        let source = try String(contentsOf: url, encoding: .utf8)
        var names: [String] = []
        for line in source.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("export type ") else { continue }
            // "export type Name = ..." -> "Name"
            let afterKeyword = trimmed.dropFirst("export type ".count)
            let name = afterKeyword.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            if !name.isEmpty { names.append(String(name)) }
        }
        return names
    }

    @Test func everyContractTypeIsMirroredOrExplicitlyExcluded() throws {
        let names = try vendoredTypeNames()
        #expect(names.count > 0, "Vendored portal.ts produced no type names — parser or snapshot is broken.")
        let accountedFor = Self.mirrored.union(Self.excluded)
        let unaccounted = names.filter { !accountedFor.contains($0) }
        #expect(unaccounted.isEmpty, "Contract types neither mirrored nor excluded: \(unaccounted.sorted())")
    }

    @Test func mirroredAndExcludedSetsDoNotOverlap() {
        #expect(Self.mirrored.isDisjoint(with: Self.excluded))
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd Packages/SlipStreamKit && swift test`
Expected: all tests pass. If `everyContractTypeIsMirroredOrExplicitlyExcluded` fails, the message lists the unaccounted type names — mirror them (in a new model) or add them to `excluded` with a reason, then re-run.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test(kit): add contract drift guard over vendored portal.ts"
```

---

## Self-Review

**1. Spec coverage** (against the F1.3 spec "In scope" list and `portal.ts`):
- `PortalUser` / `UserModuleSetting` → Plan 1 (not recreated). ✓
- Auth (`LoginRequest/Response` → Plan 1; `SignupRequest/Response`, `UpdateProfileRequest`, `ValidateInvitationResponse`, `VerifyPinResponse`) → Task 3. ✓
- `Request` (+ `RequestStatus` 8-state, `PortalMediaType`), `CreateRequestInput`, `RequestListFilters` → Tasks 1 + 4. ✓
- Search/availability (`PortalMovieSearchResult`, `PortalSeriesSearchResult`, `AvailabilityInfo`, `SlotInfo`, `SeasonAvailabilityInfo`, `EnrichedSeason`, `EnrichedEpisode`) → Task 5. ✓
- `PortalDownload` → Task 6 (+ `PortalDownloadStatus` in Task 1). ✓
- `UserNotification` / `CreateUserNotificationInput` → Task 6 (+ `JSONValue` in Task 2). ✓
- Timestamps as `String` → applied throughout (Global Constraints). ✓
- Admin/deferred types excluded → enumerated in Global Constraints and enforced by Task 7's `excluded` set. ✓
- **Deviation from the spec's "In scope" list — inbox list/count types:** intentionally excluded and documented (Global Constraints) — they live in `inbox.ts`, not `portal.ts`, and feed the cut F6.1/F6.2. If the inbox is ever revived, mirror `PortalNotification` + the list/count responses then.
- **CI drift check** (spec "iOS notes") → Task 7, implemented as a self-contained `swift test` guard over a vendored snapshot (no fragile cross-repo path dependency at test time).

**2. Placeholder scan:** No "TBD" / "add error handling" / "similar to Task N". Every code step shows the complete type with its explicit `public init`; every command has an expected result. ✓

**3. Type consistency:** Enum names (`RequestStatus`, `PortalMediaType`, `PortalDownloadStatus`, `RequestScope`) are defined in Task 1 and consumed verbatim in Tasks 4–6. `JSONValue` (Task 2) is consumed as `[String: JSONValue]` in Task 6. `PortalUser` (Plan 1) is consumed in Tasks 3–4. The Task 7 `mirrored` set lists exactly the 24 mirrored type names from Plan 1 + Tasks 1–6; the `excluded` set lists exactly the 12 names called out in Global Constraints; the two sets are asserted disjoint, and every `export type` in `portal.ts` falls in their union. ✓

**Notes for the implementer:**
- Entire plan runs headlessly: `cd Packages/SlipStreamKit && swift test`. No simulator, no XcodeBuildMCP.
- These are pure value types — no `CodingKeys` anywhere, because every Swift property name already equals its camelCase JSON key.
- If `swift test` can't resolve the platform, confirm Xcode 26 is selected (`xcode-select -p`) so `swift` is the Swift 6 toolchain.
- After Task 7, update `docs/TRACKER.md` (F1.3 → `[x]`) and the F1.3 spec status header to "complete" as part of merging this branch.
