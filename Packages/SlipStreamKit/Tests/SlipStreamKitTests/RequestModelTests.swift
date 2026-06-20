import Foundation
import Testing

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
      mediaType: .movie, title: "The Matrix", tmdbId: 603, tvdbId: nil,
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
    let filters = RequestListFilters(
      status: .available, mediaType: .series, userId: 7, scope: .mine)
    #expect(filters.status == .available)
    #expect(filters.scope == .mine)
  }
}
