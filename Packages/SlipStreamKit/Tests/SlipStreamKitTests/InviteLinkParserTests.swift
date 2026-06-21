import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct InviteLinkParserTests {
  let server = URL(string: "https://slipstream.example.com")!

  @Test func parsesFullLinkOriginAndToken() {
    let result = InviteLinkParser.parse(
      "https://invite.example.com/signup?token=ABC123", configuredServer: nil)
    #expect(result?.serverURL == URL(string: "https://invite.example.com")!)
    #expect(result?.token == "ABC123")
  }

  @Test func parsesLinkWithTrailingSlashAndFragment() {
    let result = InviteLinkParser.parse(
      "https://host.example.com/signup/?token=XYZ#welcome", configuredServer: nil)
    #expect(result?.serverURL == URL(string: "https://host.example.com")!)
    #expect(result?.token == "XYZ")
  }

  @Test func parsesLinkWithPortPreservingOrigin() {
    let result = InviteLinkParser.parse(
      "http://localhost:8080/signup?token=DEVTOK", configuredServer: nil)
    #expect(result?.serverURL == URL(string: "http://localhost:8080")!)
    #expect(result?.token == "DEVTOK")
  }

  @Test func bareTokenUsesConfiguredServer() {
    let result = InviteLinkParser.parse("BARE-TOKEN-123", configuredServer: server)
    #expect(result?.serverURL == server)
    #expect(result?.token == "BARE-TOKEN-123")
  }

  @Test func bareTokenWithoutServerIsNil() {
    #expect(InviteLinkParser.parse("BARE-TOKEN-123", configuredServer: nil) == nil)
  }

  @Test func garbageWithWhitespaceIsNil() {
    #expect(InviteLinkParser.parse("not a token", configuredServer: server) == nil)
  }

  @Test func linkWithoutTokenQueryIsNil() {
    #expect(
      InviteLinkParser.parse("https://host.example.com/signup", configuredServer: server) == nil)
  }

  @Test func blankIsNil() {
    #expect(InviteLinkParser.parse("   ", configuredServer: server) == nil)
  }

  @Test func relativeURLIshBareTokenIsNil() {
    #expect(InviteLinkParser.parse("//no-scheme-host", configuredServer: server) == nil)
  }

  @Test func bareTokenWithQueryCharsIsNil() {
    #expect(InviteLinkParser.parse("abc?token=def", configuredServer: server) == nil)
  }
}
