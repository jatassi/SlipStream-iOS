import SlipStreamKit
import SwiftUI

/// The poster-size control, bound to the shared `PosterSizePreference`. Mirrors
/// the web `PosterSizeSlider`: range 100–250 with a mobile-aware step (25 on
/// compact width, 10 on regular). Writes go through `setSize`, which clamps and
/// persists.
public struct PosterSizeSlider: View {
  private let preference: PosterSizePreference
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  public init(preference: PosterSizePreference) {
    self.preference = preference
  }

  public var body: some View {
    let step = PosterGridMetrics.step(isCompact: horizontalSizeClass == .compact)
    HStack(spacing: 8) {
      Image(systemName: "rectangle.grid.3x2")
        .foregroundStyle(DesignTheme.mutedForeground)
        .accessibilityHidden(true)
      Slider(
        value: Binding(
          get: { preference.size },
          set: { preference.setSize($0) }
        ),
        in: PosterGridMetrics.minSize...PosterGridMetrics.maxSize,
        step: step
      )
      .tint(DesignTheme.movie)
      .accessibilityLabel("Poster size")
    }
  }
}
