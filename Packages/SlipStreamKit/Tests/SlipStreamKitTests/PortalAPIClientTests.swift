import Testing
import Foundation
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
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
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
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(body.utf8))
        }
        let user = try await client().profile(token: "tok")
        #expect(user.username == "jack")
    }

    @Test func non2xxMapsToHttpErrorWithServerMessage() async throws {
        StubURLProtocol.handler = { request in
            let body = #"{"message":"invalid credentials"}"#
            let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data(body.utf8))
        }
        await #expect(throws: APIClientError.http(status: 401, message: "invalid credentials", error: nil)) {
            _ = try await client().login(LoginRequest(username: "jack", password: "0000"))
        }
    }

    @Test func statusHitsPublicPathWithoutToken() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/v1/status")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let body = #"{"portalEnabled":true,"enabledModules":{"movie":true,"tv":true}}"#
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
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
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{"ok":true}"#.utf8))
        }
        let probe: Probe = try await client().send("status", base: .status)
        #expect(probe == Probe(ok: true))
    }

    @Test func metadataBaseTargetsApiV1MetadataPathWithBearer() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/v1/metadata/movie/603")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
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
            let resp = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        // No throw == pass.
        try await client().sendNoContent("42", method: .delete, token: "tok")
    }

    @Test func sendNoContentMapsNon2xxToHttpError() async throws {
        StubURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
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
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
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
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
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
                let resp = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (resp, Data(#"{"error":"boom"}"#.utf8))
            }
            let client = PortalAPIClient(baseURL: baseURL, session: session, onUnauthorized: { fired() })
            await #expect(throws: APIClientError.self) {
                let _: Probe = try await client.send("auth/profile", token: "tok")
            }
        }
    }
}
