import Foundation
import Testing

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
