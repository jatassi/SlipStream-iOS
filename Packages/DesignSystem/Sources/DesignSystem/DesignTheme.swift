import SlipStreamKit
import SwiftUI

/// SlipStream's force-dark visual identity. Colours mirror the web portal's
/// dark-theme tokens in `web/src/index.css`; the web defines them in OKLCH, which
/// SwiftUI cannot express directly, so each is converted to sRGB hex with its
/// OKLCH source noted inline. The app runs dark-only (`.preferredColorScheme(.dark)`).
public enum DesignTheme {
  // MARK: Semantic
  public static let background = Color(hex: 0x0A0A0A)  // oklch(0.145 0 0)
  public static let surface = Color(hex: 0x171717)  // oklch(0.205 0 0) — card
  public static let foreground = Color(hex: 0xFAFAFA)  // oklch(0.985 0 0)
  public static let muted = Color(hex: 0x262626)  // oklch(0.269 0 0)
  public static let mutedForeground = Color(hex: 0xA1A1A1)  // oklch(0.708 0 0)
  public static let accent = Color(hex: 0x404040)  // oklch(0.371 0 0)
  public static let ring = Color(hex: 0x737373)  // oklch(0.556 0 0)
  public static let destructive = Color(hex: 0xFF6467)  // oklch(0.704 0.191 22.216)
  public static let border = Color.white.opacity(0.10)  // white @ 10%

  // MARK: Brand — movie (orange) / tv (blue)
  public static let movie = Color(hex: 0xEF852E)  // oklch(0.72 0.16 55) — movie-500
  public static let movieMuted = Color(hex: 0xB6501F)  // movie-700
  public static let movieVibrant = Color(hex: 0xF29E46)  // movie-400
  public static let tv = Color(hex: 0x009FF6)  // oklch(0.675 0.17 243) — tv-500
  public static let tvMuted = Color(hex: 0x0066B0)  // tv-700
  public static let tvVibrant = Color(hex: 0x26B7FF)  // tv-400

  /// The SlipStream brand gradient: movie-orange → tv-blue, left to right
  /// (web `bg-media-gradient`).
  public static let mediaGradient = LinearGradient(
    colors: [movie, tv], startPoint: .leading, endPoint: .trailing)

  /// Install runtime design dependencies once, at launch, before any view renders.
  /// (Inter font registration is added in Task 5.)
  @MainActor public static func bootstrap() {
    PosterImagePipeline.configure()
    Typography.registerFonts()
  }
}

/// Maps the contract's media type to its brand accent and fallback glyph — the
/// iOS analogue of the web's per-type tinting (`movie` orange / `tv` blue) and
/// `FallbackIcon` (`Film` / `Tv`).
extension ModuleType {
  public var accentColor: Color {
    switch self {
    case .movie: DesignTheme.movie
    case .tv: DesignTheme.tv
    }
  }

  public var fallbackSymbol: String {
    switch self {
    case .movie: "film"
    case .tv: "tv"
    }
  }
}
