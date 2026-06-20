import Foundation
import Testing

@testable import SlipStreamKit

/// Fails when the vendored `portal.ts` snapshot contains an `export type` that is
/// neither mirrored in Swift nor explicitly excluded — i.e. the contract drifted
/// and the Swift models (or this manifest) were not updated to match.
///
/// Scope: this is a *type-name* guard. It catches an `export type` being added to
/// or removed from the contract; it does NOT catch a *field* being added to or
/// changed on an already-mirrored type. After re-vendoring the snapshot, a green
/// run means "no new/removed top-level types," not "every field still matches" —
/// field-level fidelity is enforced by the per-type decode tests, not here.
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
    #expect(
      !names.isEmpty, "Vendored portal.ts produced no type names — parser or snapshot is broken.")
    let accountedFor = Self.mirrored.union(Self.excluded)
    let unaccounted = names.filter { !accountedFor.contains($0) }
    #expect(
      unaccounted.isEmpty, "Contract types neither mirrored nor excluded: \(unaccounted.sorted())")
  }

  @Test func mirroredAndExcludedSetsDoNotOverlap() {
    #expect(Self.mirrored.isDisjoint(with: Self.excluded))
  }
}
