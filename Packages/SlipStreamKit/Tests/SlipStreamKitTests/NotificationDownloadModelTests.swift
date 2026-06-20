import Foundation
import Testing

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
