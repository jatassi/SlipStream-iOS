import SwiftUI

extension Color {
  /// Build an sRGB colour from a `0xRRGGBB` literal. Used by `DesignTheme` for
  /// the web tokens (whose OKLCH values were converted to sRGB hex).
  init(hex: UInt32) {
    let red = Double((hex >> 16) & 0xFF) / 255
    let green = Double((hex >> 8) & 0xFF) / 255
    let blue = Double(hex & 0xFF) / 255
    self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
  }
}
