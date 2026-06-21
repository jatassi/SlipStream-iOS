import NukeUI
import SlipStreamKit
import SwiftUI

/// A cached poster image in the portal's 2:3 portrait format with a `rounded-lg`
/// corner. Shows a muted pulse while loading, scales the image to fill on
/// success, and falls back to a `ModuleType`-tinted film/tv glyph on failure
/// (web `PosterImage` + `FallbackIcon`). The `url` is the server-resolved
/// `posterUrl`; building artwork URLs is Epic 03's concern.
public struct PosterImage: View {
  private let url: URL?
  private let module: ModuleType
  private let cornerRadius: CGFloat

  public init(url: URL?, module: ModuleType, cornerRadius: CGFloat = RadiusScale.base) {
    self.url = url
    self.module = module
    self.cornerRadius = cornerRadius
  }

  public var body: some View {
    Color.clear
      .aspectRatio(2.0 / 3.0, contentMode: .fit)
      .overlay {
        LazyImage(url: url) { state in
          if let image = state.image {
            image.resizable().scaledToFill()
          } else if state.error != nil {
            fallback
          } else {
            DesignTheme.muted.pulsing()
          }
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(DesignTheme.border, lineWidth: 1)
      }
  }

  private var fallback: some View {
    ZStack {
      DesignTheme.muted
      Image(systemName: module.fallbackSymbol)
        .font(.system(size: 36))
        .foregroundStyle(module.accentColor)
        .accessibilityHidden(true)
    }
  }
}

#Preview("PosterImage") {
  HStack(spacing: 12) {
    PosterImage(url: nil, module: .movie)
    PosterImage(url: nil, module: .tv)
  }
  .frame(height: 240)
  .padding()
  .background(DesignTheme.background)
}
