import Foundation

/// Developer launch overrides read from the process environment, so live testing can
/// target a local SlipStream dev server without hand-typing URLs or credentials.
///
/// Set these in the `SlipStream` Run scheme's environment variables (Debug only):
/// - `SLIPSTREAM_BASE_URL`     e.g. `http://localhost:8080` or `http://my-mac.local:8080`
/// - `SLIPSTREAM_DEV_USERNAME` the throwaway portal test user
/// - `SLIPSTREAM_DEV_PIN`      that user's 4-digit PIN
///
/// Parsing lives here — not in the view — so it stays unit-testable with an injected
/// environment dictionary. The same env vars are the seam future automated integration
/// tests use to point the app at a server without driving any UI.
public struct DevLaunchConfig: Sendable, Equatable {
  public let baseURLOverride: URL?
  public let devUsername: String?
  public let devPIN: String?

  public init(environment: [String: String]) {
    func nonEmpty(_ key: String) -> String? {
      guard let value = environment[key], !value.isEmpty else { return nil }
      return value
    }
    self.baseURLOverride = nonEmpty("SLIPSTREAM_BASE_URL").flatMap(URL.init(string:))
    self.devUsername = nonEmpty("SLIPSTREAM_DEV_USERNAME")
    self.devPIN = nonEmpty("SLIPSTREAM_DEV_PIN")
  }

  /// Overrides from the live process environment, read once at first access.
  public static let current = DevLaunchConfig(environment: ProcessInfo.processInfo.environment)
}
