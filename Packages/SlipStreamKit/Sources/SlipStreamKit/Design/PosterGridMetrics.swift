import CoreGraphics

/// Pure poster-grid sizing, mirroring the web portal's `posterSize` UI store
/// (`web/src/stores/ui.ts`) and the `PosterSizeSlider` in
/// `web/src/routes/requests/library.tsx`. `size` is the minimum item width in
/// points, fed to `GridItem(.adaptive(minimum:))` — the SwiftUI equivalent of
/// the web's `repeat(auto-fill, minmax(posterSize, 1fr))`.
public enum PosterGridMetrics {
  /// Smallest allowed minimum item width (web slider `min`).
  public static let minSize: CGFloat = 100
  /// Largest allowed minimum item width (web slider `max`).
  public static let maxSize: CGFloat = 250
  /// Default minimum item width (web store default).
  public static let defaultSize: CGFloat = 150
  /// Slider step on compact width / phones (`isMobile ? 25`).
  public static let compactStep: CGFloat = 25
  /// Slider step on regular width / iPad + Mac (`: 10`).
  public static let regularStep: CGFloat = 10
  /// Grid gutter for the adaptive media/library poster grid. Re-verified against
  /// current web source (Task 1 Step 1): the canonical `MediaGrid`
  /// (`web/src/components/media/media-grid.tsx`) and library `GridSkeleton`
  /// (`routes/requests/library.tsx`) both use `gap-4` (16px) — this is the grid
  /// `PosterGrid` mirrors. (The search grids — `expandable-media-grid.tsx`,
  /// `search-loading-skeleton.tsx` — use `gap-3`/12px; `SearchLoadingSkeleton`
  /// passes that value explicitly.)
  public static let spacing: CGFloat = 16

  /// Clamp a requested size into the supported range.
  public static func clamp(_ size: CGFloat) -> CGFloat {
    min(max(size, minSize), maxSize)
  }

  /// The poster-size slider step for the current width class.
  public static func step(isCompact: Bool) -> CGFloat {
    isCompact ? compactStep : regularStep
  }
}
