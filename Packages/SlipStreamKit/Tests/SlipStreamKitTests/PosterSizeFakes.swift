import CoreGraphics

@testable import SlipStreamKit

final class FakePosterSizeStore: PosterSizeStoring, @unchecked Sendable {
  var stored: CGFloat?
  private(set) var saveCount = 0
  init(stored: CGFloat? = nil) { self.stored = stored }
  func loadPosterSize() -> CGFloat? { stored }
  func savePosterSize(_ size: CGFloat) {
    stored = size
    saveCount += 1
  }
}
