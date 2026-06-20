import Foundation
import Testing

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
