import Foundation

/// Pulls a server origin + invitation token out of a pasted invitation. Accepts a full
/// `https://host/…/signup?token=…` URL (used to bootstrap the server origin for a brand-new
/// user) or, when a server is already configured, a bare token string.
public enum InviteLinkParser {
  private static let tokenCharacters = Set(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=")

  public struct Result: Equatable, Sendable {
    public let serverURL: URL
    public let token: String
    public init(serverURL: URL, token: String) {
      self.serverURL = serverURL
      self.token = token
    }
  }

  /// Returns `nil` when the input is neither a `http(s)` URL carrying a non-empty `token`
  /// query item nor (with `configuredServer` set) a plain whitespace-free bare token.
  public static func parse(_ input: String, configuredServer: URL?) -> Result? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if let components = URLComponents(string: trimmed),
      let scheme = components.scheme?.lowercased(),
      scheme == "https" || scheme == "http",
      let host = components.host, !host.isEmpty,
      let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
      !token.isEmpty
    {
      var origin = URLComponents()
      origin.scheme = scheme
      origin.host = host
      origin.port = components.port
      if let url = origin.url {
        return Result(serverURL: url, token: token)
      }
    }

    // Bare token: only meaningful when we already know which server to hit, and only when the
    // input is a plain base64url token (alphanumerics + `-` `_` and `=` padding) — not a relative
    // URL reference, scheme, query, or whitespace. Anything outside that set is not a token we
    // should forward to the server.
    if let configuredServer, !trimmed.isEmpty, trimmed.allSatisfy(tokenCharacters.contains) {
      return Result(serverURL: configuredServer, token: trimmed)
    }

    return nil
  }
}
