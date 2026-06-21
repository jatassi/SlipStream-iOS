import SlipStreamKit
import SwiftUI

/// One muted, pulsing-and-shimmering 2:3 poster placeholder — the web's
/// `bg-muted aspect-[2/3] animate-pulse rounded-lg` cell with the skeleton sweep.
public struct PosterCellSkeleton: View {
  private let cornerRadius: CGFloat

  public init(cornerRadius: CGFloat = RadiusScale.base) {
    self.cornerRadius = cornerRadius
  }

  public var body: some View {
    Color.clear
      .aspectRatio(2.0 / 3.0, contentMode: .fit)
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(DesignTheme.muted)
          .pulsing()
          .shimmering()
      }
  }
}

/// A full grid of poster placeholders, mirroring the web `GridSkeleton`
/// (12 cells, adaptive columns, `gap-4`/16pt — `PosterGridMetrics.spacing`).
public struct PosterGridSkeleton: View {
  private let count: Int
  private let minItemWidth: CGFloat
  private let spacing: CGFloat

  public init(
    count: Int = 12,
    minItemWidth: CGFloat = PosterGridMetrics.defaultSize,
    spacing: CGFloat = PosterGridMetrics.spacing
  ) {
    self.count = count
    self.minItemWidth = minItemWidth
    self.spacing = spacing
  }

  public var body: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: minItemWidth), spacing: spacing)],
      spacing: spacing
    ) {
      ForEach(0..<count, id: \.self) { _ in
        PosterCellSkeleton()
      }
    }
  }
}

/// The denser placeholder grid for search results, mirroring the web
/// `SearchLoadingSkeleton` (12 smaller cells). The search grids use `gap-3`
/// (12pt) — not the library grid's `gap-4` — so the gap is passed explicitly.
public struct SearchLoadingSkeleton: View {
  /// Search-grid gutter (`gap-3` = 12pt), distinct from the library grid's 16pt.
  private static let searchSpacing: CGFloat = 12
  private let count: Int

  public init(count: Int = 12) {
    self.count = count
  }

  public var body: some View {
    PosterGridSkeleton(count: count, minItemWidth: 100, spacing: Self.searchSpacing)
  }
}

#Preview("PosterGridSkeleton") {
  ScrollView { PosterGridSkeleton().padding() }
    .background(DesignTheme.background)
}
