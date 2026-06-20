import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct ModelDecodingTests {
  @Test func decodesLoginResponseWithNestedUser() throws {
    let json = """
      {
        "token": "jwt.abc.def",
        "isAdmin": false,
        "user": {
          "id": 7,
          "username": "jack",
          "moduleSettings": [
            { "moduleType": "movie", "qualityProfileId": 3 },
            { "moduleType": "tv", "qualityProfileId": null }
          ],
          "autoApprove": true,
          "enabled": true,
          "isAdmin": false,
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-02T00:00:00Z"
        }
      }
      """
    let data = Data(json.utf8)
    let resp = try JSONDecoder().decode(LoginResponse.self, from: data)

    #expect(resp.token == "jwt.abc.def")
    #expect(resp.isAdmin == false)
    #expect(resp.user.id == 7)
    #expect(resp.user.username == "jack")
    #expect(resp.user.moduleSettings.count == 2)
    #expect(resp.user.moduleSettings[0].qualityProfileId == 3)
    #expect(resp.user.moduleSettings[1].qualityProfileId == nil)
    #expect(resp.user.autoApprove == true)
    #expect(resp.user.enabled == true)
    #expect(resp.user.createdAt == "2026-01-01T00:00:00Z")
    #expect(resp.user.updatedAt == "2026-01-02T00:00:00Z")
  }

  @Test func encodesLoginRequestWithPasswordField() throws {
    let body = LoginRequest(username: "jack", password: "1234")
    let data = try JSONEncoder().encode(body)
    let obj = try JSONSerialization.jsonObject(with: data) as? [String: String]
    #expect(obj?["username"] == "jack")
    #expect(obj?["password"] == "1234")
  }
}
