import Foundation

/// Non-secret persistence of the last successfully signed-in username. The iOS
/// analogue of the web portal's `localStorage 'slipstream_last_username'`, used to
/// collapse the username into a chip so returning users only type their PIN.
public protocol LastUsernameStore: Sendable {
  var lastUsername: String? { get }
  func setLastUsername(_ username: String)
}

/// Real `UserDefaults`-backed implementation. The username is not a secret, so
/// `UserDefaults` (not the Keychain) is the right home — matching the web's
/// `localStorage` choice and the other non-secret stores in this module.
public final class UserDefaultsLastUsernameStore: LastUsernameStore, @unchecked Sendable {
  private let defaults: UserDefaults
  private let key = "slipstream.lastUsername"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public var lastUsername: String? {
    defaults.string(forKey: key)
  }

  public func setLastUsername(_ username: String) {
    defaults.set(username, forKey: key)
  }
}
