/// The auth surface AuthStore depends on. Backed by PortalAPIClient; faked in tests.
public protocol AuthAPI: Sendable {
  func login(_ body: LoginRequest) async throws -> LoginResponse
  func profile(token: String) async throws -> PortalUser
  /// Validate an invitation token (tokenless). Throws `APIClientError.http(404/410/409)`
  /// for not-found / expired / already-used.
  func validateInvitation(token: String) async throws -> ValidateInvitationResponse
  /// Redeem an invitation with a new PIN (tokenless). Returns the session `{token, user}`.
  func signup(_ body: SignupRequest) async throws -> SignupResponse
}
