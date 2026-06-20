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
    title: String,
    tmdbId: Int? = nil,
    tvdbId: Int? = nil,
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
