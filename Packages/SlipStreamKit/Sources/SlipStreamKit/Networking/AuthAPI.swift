/// The auth surface AuthStore depends on. Backed by PortalAPIClient; faked in tests.
public protocol AuthAPI: Sendable {
    func login(_ body: LoginRequest) async throws -> LoginResponse
    func profile(token: String) async throws -> PortalUser
}
