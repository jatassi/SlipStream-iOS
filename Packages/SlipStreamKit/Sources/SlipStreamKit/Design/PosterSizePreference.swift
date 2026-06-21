import CoreGraphics
import Foundation
import Observation

/// The shared, observable poster-size preference. One instance is injected via
/// the SwiftUI environment and reused across every media surface, mirroring the
/// web's single shared UI store. `size` is the grid's minimum item width.
@MainActor
@Observable
public final class PosterSizePreference {
  public private(set) var size: CGFloat
  private let store: PosterSizeStoring

  public init(store: PosterSizeStoring) {
    self.store = store
    self.size = PosterGridMetrics.clamp(store.loadPosterSize() ?? PosterGridMetrics.defaultSize)
  }

  /// Clamp into the supported range, update, and persist.
  public func setSize(_ newSize: CGFloat) {
    let clamped = PosterGridMetrics.clamp(newSize)
    size = clamped
    store.savePosterSize(clamped)
  }
}
