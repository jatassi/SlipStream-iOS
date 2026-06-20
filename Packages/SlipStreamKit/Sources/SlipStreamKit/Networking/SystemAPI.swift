/// The system-discovery surface SystemStore depends on. Backed by PortalAPIClient; faked in tests.
/// `status()` hits the public `GET /api/v1/status` (no token required).
public protocol SystemAPI: Sendable {
  func status() async throws -> SystemStatus
}
