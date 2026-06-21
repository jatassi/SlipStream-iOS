import CoreGraphics
import Testing

@testable import SlipStreamKit

@Suite struct DesignConstantsTests {
  @Test func radiusScaleMatchesWebRadius() {
    // --radius: 0.45rem ≈ 7pt (Tailwind rounded-lg); badges are pill-shaped.
    #expect(RadiusScale.base == 7)
    #expect(RadiusScale.small == 4)
    #expect(RadiusScale.pill == 999)
  }

  @Test func typeScaleMatchesWebSizes() {
    #expect(TypeScale.pageTitle == 24)
    #expect(TypeScale.section == 20)
    #expect(TypeScale.cardTitle == 16)
    #expect(TypeScale.body == 14)
    #expect(TypeScale.metadata == 12)
    #expect(TypeScale.badge == 10)
  }
}
