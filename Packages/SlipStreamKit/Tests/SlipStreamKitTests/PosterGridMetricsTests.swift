import CoreGraphics
import Testing

@testable import SlipStreamKit

@Suite struct PosterGridMetricsTests {
  @Test func constantsMatchTheWebPortal() {
    #expect(PosterGridMetrics.minSize == 100)
    #expect(PosterGridMetrics.maxSize == 250)
    #expect(PosterGridMetrics.defaultSize == 150)
    // Re-verified against current web source: the adaptive media/library poster
    // grid (`MediaGrid`, library `GridSkeleton`) uses `gap-4` = 16px.
    #expect(PosterGridMetrics.spacing == 16)
  }

  @Test func clampPassesValuesWithinRange() {
    #expect(PosterGridMetrics.clamp(150) == 150)
    #expect(PosterGridMetrics.clamp(100) == 100)
    #expect(PosterGridMetrics.clamp(250) == 250)
  }

  @Test func clampFloorsBelowMinimum() {
    #expect(PosterGridMetrics.clamp(40) == 100)
  }

  @Test func clampCeilsAboveMaximum() {
    #expect(PosterGridMetrics.clamp(900) == 250)
  }

  @Test func stepIsMobileAware() {
    #expect(PosterGridMetrics.step(isCompact: true) == 25)
    #expect(PosterGridMetrics.step(isCompact: false) == 10)
  }
}
