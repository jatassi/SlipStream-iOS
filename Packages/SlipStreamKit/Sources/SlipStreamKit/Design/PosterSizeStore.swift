import CoreGraphics
import Foundation

/// Persistence seam for the poster-size preference. The iOS analogue of the
/// web's persisted `posterSize` field in the `slipstream-ui` localStorage store.
public protocol PosterSizeStoring: Sendable {
  func loadPosterSize() -> CGFloat?
  func savePosterSize(_ size: CGFloat)
}

/// Real `UserDefaults`-backed implementation. Poster size is a non-secret UI
/// preference, so `UserDefaults` (not the Keychain) is the right home.
public final class UserDefaultsPosterSizeStore: PosterSizeStoring, @unchecked Sendable {
  private let defaults: UserDefaults
  private let key = "slipstream.posterSize"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func loadPosterSize() -> CGFloat? {
    guard defaults.object(forKey: key) != nil else { return nil }
    return CGFloat(defaults.double(forKey: key))
  }

  public func savePosterSize(_ size: CGFloat) {
    defaults.set(Double(size), forKey: key)
  }
}
