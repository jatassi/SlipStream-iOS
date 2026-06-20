import Foundation

/// Compile-time posture for insecure local servers. Debug builds may talk plain HTTP to
/// local hosts (paired with the Debug-only `NSAllowsLocalNetworking` ATS exception);
/// Release stays strictly HTTPS, so shipping builds are unchanged.
public enum DevSupport {
  public static var allowsInsecureLocalServers: Bool {
    #if DEBUG
      true
    #else
      false
    #endif
  }
}

/// Validates a user-entered server origin before sign-in.
///
/// HTTPS is always acceptable. Plain HTTP is acceptable only to local hosts and only when
/// `allowInsecureLocal` is true — this mirrors exactly what `NSAllowsLocalNetworking`
/// permits at the network layer, so the Sign-In button never enables a request that ATS
/// would then reject.
public enum ServerURLValidator {
  public static func isAcceptable(_ url: URL, allowInsecureLocal: Bool) -> Bool {
    guard let scheme = url.scheme?.lowercased(),
      let host = url.host, !host.isEmpty
    else { return false }
    switch scheme {
    case "https": return true
    case "http": return allowInsecureLocal && isLocalHost(host)
    default: return false
    }
  }

  /// Hosts reachable over plain HTTP under `NSAllowsLocalNetworking`:
  /// loopback, Bonjour `.local` names, and bare (dot-less) hostnames.
  public static func isLocalHost(_ host: String) -> Bool {
    let lowercasedHost = host.lowercased()
    return lowercasedHost == "localhost"
      || lowercasedHost == "127.0.0.1"
      || lowercasedHost == "::1"
      || lowercasedHost.hasSuffix(".local")
      || !lowercasedHost.contains(".")
  }
}
