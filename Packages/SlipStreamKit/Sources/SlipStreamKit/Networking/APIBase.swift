/// The three API roots the client can target on the SlipStream HTTPS origin.
///
/// All three hang off the user's base URL; each contributes a different path prefix.
/// `portal` is the audience-scoped portal surface; `metadata` is the shared metadata
/// group (accepts the portal token); `status` is the public, unauthenticated status
/// endpoint. `metadata` and `status` live on `/api/v1`, outside the `/api/v1/requests`
/// portal base.
public enum APIBase: Sendable {
  case portal
  case metadata
  case status

  /// Path prefix appended to the base URL before the call's own path.
  var pathPrefix: String {
    switch self {
    case .portal: "api/v1/requests"
    case .metadata: "api/v1/metadata"
    case .status: "api/v1"
    }
  }
}
