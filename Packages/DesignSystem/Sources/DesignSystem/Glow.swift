import SlipStreamKit
import SwiftUI

extension View {
  /// A neon glow — the iOS analogue of the web's `glow-movie` / `glow-tv`
  /// (`box-shadow: 0 0 15px <accent>`). Apply to selected/active media cards.
  public func glow(_ color: Color, radius: CGFloat = 15) -> some View {
    shadow(color: color.opacity(0.85), radius: radius)
  }

  /// Glow tinted by media type (movie = orange, tv = blue).
  public func glow(_ module: ModuleType, radius: CGFloat = 15) -> some View {
    glow(module.accentColor, radius: radius)
  }
}
