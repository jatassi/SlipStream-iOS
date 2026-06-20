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
    title: String,
    tvdbId: Int? = nil,
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
    hasFile: Bool,
    monitored: Bool,
    aired: Bool,
    overview: String? = nil,
    airDate: String? = nil,
    runtime: Int? = nil,
    imdbRating: Double? = nil
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
    inLibrary: Bool,
    available: Bool,
    monitored: Bool,
    airedEpisodesWithFiles: Int,
    totalAiredEpisodes: Int,
    episodeCount: Int,
    overview: String? = nil,
    posterUrl: String? = nil,
    airDate: String? = nil,
    episodes: [EnrichedEpisode]? = nil,
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
