import Foundation
import Testing

@testable import SlipStreamKit

@Suite(.serialized) struct PortalAPIClientTests {
  let baseURL = URL(string: "https://slipstream.example.com")!

  private func client() -> PortalAPIClient {
    PortalAPIClient(baseURL: baseURL, session: StubURLProtocol.makeSession())
  }

  /// Minimal decodable fixture for exercising the request plumbing without a real model.
  private struct Probe: Decodable, Equatable { let ok: Bool }

  @Test func loginHitsCorrectPathAndDecodes() async throws {
    StubURLProtocol.handler = { request in
      #expect(request.url?.path == "/api/v1/requests/auth/login")
      #expect(request.httpMethod == "POST")
      let body = """
        {"token":"tok","isAdmin":false,
         "user":{"id":1,"username":"jack","moduleSettings":[],
                 "autoApprove":true,"enabled":true,"isAdmin":false,
                 "createdAt":"t","updatedAt":"t"}}
        """
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (resp, Data(body.utf8))
    }
    let resp = try await client().login(LoginRequest(username: "jack", password: "1234"))
    #expect(resp.token == "tok")
    #expect(resp.user.username == "jack")
  }

  @Test func profileSendsBearerHeader() async throws {
    StubURLProtocol.handler = { request in
      #expect(request.url?.path == "/api/v1/requests/auth/profile")
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
      let body = """
        {"id":1,"username":"jack","moduleSettings":[],
         "autoApprove":true,"enabled":true,"isAdmin":false,
         "createdAt":"t","updatedAt":"t"}
        """
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (resp, Data(body.utf8))
    }
    let user = try await client().profile(token: "tok")
    #expect(user.username == "jack")
  }

  @Test func non2xxMapsToHttpErrorWithServerMessage() async throws {
    StubURLProtocol.handler = { request in
      let body = #"{"message":"invalid credentials"}"#
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
      return (resp, Data(body.utf8))
    }
    await #expect(
      throws: APIClientError.http(status: 401, message: "invalid credentials", error: nil)
    ) {
      _ = try await client().login(LoginRequest(username: "jack", password: "0000"))
    }
  }

  @Test func statusHitsPublicPathWithoutToken() async throws {
    StubURLProtocol.handler = { request in
      #expect(request.url?.path == "/api/v1/status")
      #expect(request.httpMethod == "GET")
      #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
      let body = #"{"portalEnabled":true,"enabledModules":{"movie":true,"tv":true}}"#
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (resp, Data(body.utf8))
    }
    let status = try await client().status()
    #expect(status.portalEnabled == true)
    #expect(status.enabledModuleTypes == [.movie, .tv])
  }

  @Test func statusBaseTargetsPublicApiV1Path() async throws {
    StubURLProtocol.handler = { request in
      #expect(request.url?.path == "/api/v1/status")
      #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (resp, Data(#"{"ok":true}"#.utf8))
    }
    let probe: Probe = try await client().send("status", base: .status)
    #expect(probe == Probe(ok: true))
  }

  @Test func metadataBaseTargetsApiV1MetadataPathWithBearer() async throws {
    StubURLProtocol.handler = { request in
      #expect(request.url?.path == "/api/v1/metadata/movie/603")
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (resp, Data(#"{"ok":true}"#.utf8))
    }
    let probe: Probe = try await client().send("movie/603", base: .metadata, token: "tok")
    #expect(probe == Probe(ok: true))
  }

  @Test func sendNoContentSucceedsOn204() async throws {
    StubURLProtocol.handler = { request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url?.path == "/api/v1/requests/42")
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
      return (resp, Data())
    }
    // No throw == pass.
    try await client().sendNoContent("42", method: .delete, token: "tok")
  }

  @Test func sendNoContentMapsNon2xxToHttpError() async throws {
    StubURLProtocol.handler = { request in
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
      return (resp, Data(#"{"error":"not found"}"#.utf8))
    }
    await #expect(throws: APIClientError.http(status: 404, message: nil, error: "not found")) {
      try await client().sendNoContent("999", method: .delete, token: "tok")
    }
  }

  @Test func tokenBearing401FiresUnauthorizedHookOnce() async throws {
    await confirmation("onUnauthorized fires once") { fired in
      let session = StubURLProtocol.makeSession()
      StubURLProtocol.handler = { request in
        let resp = HTTPURLResponse(
          url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        return (resp, Data(#"{"message":"expired"}"#.utf8))
      }
      let client = PortalAPIClient(baseURL: baseURL, session: session, onUnauthorized: { fired() })
      await #expect(throws: APIClientError.self) {
        let _: Probe = try await client.send("auth/profile", token: "expired-tok")
      }
    }
  }

  @Test func noToken401DoesNotFireHook() async throws {
    await confirmation("hook never fires", expectedCount: 0) { fired in
      let session = StubURLProtocol.makeSession()
      StubURLProtocol.handler = { request in
        let resp = HTTPURLResponse(
          url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        return (resp, Data(#"{"message":"bad creds"}"#.utf8))
      }
      let client = PortalAPIClient(baseURL: baseURL, session: session, onUnauthorized: { fired() })
      await #expect(throws: APIClientError.self) {
        _ = try await client.login(LoginRequest(username: "jack", password: "0000"))
      }
    }
  }

  @Test func non401ErrorDoesNotFireHook() async throws {
    await confirmation("hook never fires", expectedCount: 0) { fired in
      let session = StubURLProtocol.makeSession()
      StubURLProtocol.handler = { request in
        let resp = HTTPURLResponse(
          url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        return (resp, Data(#"{"error":"boom"}"#.utf8))
      }
      let client = PortalAPIClient(baseURL: baseURL, session: session, onUnauthorized: { fired() })
      await #expect(throws: APIClientError.self) {
        let _: Probe = try await client.send("auth/profile", token: "tok")
      }
    }
  }

  @Test func validateInvitationHitsPathWithEncodedTokenQuery() async throws {
    let token = "AbC-_123=="  // base64url-style: url-safe chars + padding
    StubURLProtocol.handler = { request in
      #expect(request.url?.path == "/api/v1/requests/auth/validate-invitation")
      #expect(request.httpMethod == "GET")
      #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
      let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
      #expect(items?.first(where: { $0.name == "token" })?.value == token)
      let body = #"{"valid":true,"username":"newbie","expiresAt":"2026-06-27T10:30:00Z"}"#
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (resp, Data(body.utf8))
    }
    let resp = try await client().validateInvitation(token: token)
    #expect(resp.valid == true)
    #expect(resp.username == "newbie")
  }

  @Test func validateInvitationMaps410ToHttpError() async throws {
    StubURLProtocol.handler = { request in
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 410, httpVersion: nil, headerFields: nil)!
      return (resp, Data(#"{"error":"invitation has expired"}"#.utf8))
    }
    await #expect(
      throws: APIClientError.http(status: 410, message: nil, error: "invitation has expired")
    ) {
      _ = try await client().validateInvitation(token: "expired")
    }
  }

  @Test func signupPostsToSignupPathAndDecodes() async throws {
    StubURLProtocol.handler = { request in
      #expect(request.url?.path == "/api/v1/requests/auth/signup")
      #expect(request.httpMethod == "POST")
      #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
      let body = """
        {"token":"session-jwt",
         "user":{"id":7,"username":"newbie","moduleSettings":[],
                 "autoApprove":false,"enabled":true,"isAdmin":false,
                 "createdAt":"t","updatedAt":"t"}}
        """
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
      return (resp, Data(body.utf8))
    }
    let resp = try await client().signup(SignupRequest(token: "invite-tok", password: "1234"))
    #expect(resp.token == "session-jwt")
    #expect(resp.user.username == "newbie")
  }

  @Test func libraryMoviesHitsPortalPathWithBearerAndDecodes() async throws {
    StubURLProtocol.handler = { request in
      #expect(request.url?.path == "/api/v1/requests/library/movies")
      #expect(request.httpMethod == "GET")
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
      let body = """
        [{"id":1,"tmdbId":603,"title":"The Matrix","year":1999,
          "overview":"o","posterUrl":"https://x/p.jpg","backdropUrl":null}]
        """
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (resp, Data(body.utf8))
    }
    let movies = try await client().libraryMovies(token: "tok")
    #expect(movies.count == 1)
    #expect(movies.first?.title == "The Matrix")
    #expect(movies.first?.tmdbId == 603)
  }

  @Test func librarySeriesHitsPortalPathWithBearerAndDecodes() async throws {
    StubURLProtocol.handler = { request in
      #expect(request.url?.path == "/api/v1/requests/library/series")
      #expect(request.httpMethod == "GET")
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
      let body = """
        [{"id":2,"tmdbId":1399,"tvdbId":121361,"title":"Game of Thrones","year":2011,
          "overview":"o","posterUrl":null,"backdropUrl":null,"network":"HBO"}]
        """
      let resp = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (resp, Data(body.utf8))
    }
    let series = try await client().librarySeries(token: "tok")
    #expect(series.count == 1)
    #expect(series.first?.title == "Game of Thrones")
    #expect(series.first?.tvdbId == 121361)
  }
}
