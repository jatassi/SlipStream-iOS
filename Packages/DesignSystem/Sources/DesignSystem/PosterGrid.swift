import SlipStreamKit
import SwiftUI

/// An adaptive poster grid: as many columns of at least `minItemWidth` as fit,
/// each growing to fill the row — the SwiftUI equivalent of the web's
/// `grid-template-columns: repeat(auto-fill, minmax(posterSize, 1fr))`. Renders a
/// bare `LazyVGrid`; wrap it in a `ScrollView` at the call site.
public struct PosterGrid<Item: Identifiable, Cell: View>: View {
  private let items: [Item]
  private let minItemWidth: CGFloat
  private let spacing: CGFloat
  private let cell: (Item) -> Cell

  public init(
    items: [Item],
    minItemWidth: CGFloat,
    spacing: CGFloat = PosterGridMetrics.spacing,
    @ViewBuilder cell: @escaping (Item) -> Cell
  ) {
    self.items = items
    self.minItemWidth = minItemWidth
    self.spacing = spacing
    self.cell = cell
  }

  public var body: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: minItemWidth), spacing: spacing)],
      spacing: spacing
    ) {
      ForEach(items) { item in
        cell(item)
      }
    }
  }
}
