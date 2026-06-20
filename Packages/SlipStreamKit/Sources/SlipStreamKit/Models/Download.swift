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
    requestId: Int,
    requestTitle: String,
    season: Int? = nil,
    episode: Int? = nil,
    movieId: Int? = nil,
    seriesId: Int? = nil,
    seasonNumber: Int? = nil,
    isSeasonPack: Bool? = nil,
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
