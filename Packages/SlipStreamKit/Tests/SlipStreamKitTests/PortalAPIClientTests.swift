import Testing
import Foundation
@testable import SlipStreamKit

@Suite(.serialized) struct PortalAPIClientTests {
    let baseURL = URL(string: "https://slipstream.example.com")!

    private func client() -> PortalAPIClient {
        PortalAPIClient(baseURL: baseURL, session: StubURLProtocol.makeSession())
    }

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
}
