import CoreText
import SlipStreamKit
import SwiftUI

/// Registers the bundled Inter Variable typeface and exposes the SlipStream font
/// ramp. Inter is the web portal's `--font-sans`; sizes mirror its `text-*` usage
/// via `TypeScale`. Call `registerFonts()` once at launch (from `DesignTheme.bootstrap`).
public enum Typography {
  /// PostScript name of the bundled variable face.
  static let familyName = "InterVariable"

  public static func registerFonts() {
    guard let url = Bundle.module.url(forResource: "InterVariable", withExtension: "ttf") else {
      return
    }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }
}

extension Font {
  /// Page title — `text-2xl` semibold.
  public static let ssPageTitle =
    Font.custom(Typography.familyName, size: TypeScale.pageTitle, relativeTo: .title).weight(
      .semibold)
  /// Section heading — `text-xl` semibold.
  public static let ssSection =
    Font.custom(Typography.familyName, size: TypeScale.section, relativeTo: .title2).weight(
      .semibold)
  /// Card title — `text-base` medium.
  public static let ssCardTitle =
    Font.custom(Typography.familyName, size: TypeScale.cardTitle, relativeTo: .headline).weight(
      .medium)
  /// Body copy — `text-sm`.
  public static let ssBody =
    Font.custom(Typography.familyName, size: TypeScale.body, relativeTo: .body)
  /// Metadata / timestamps — `text-xs`.
  public static let ssMetadata =
    Font.custom(Typography.familyName, size: TypeScale.metadata, relativeTo: .caption)
  /// Badge label — `text-[10px]` medium.
  public static let ssBadge =
    Font.custom(Typography.familyName, size: TypeScale.badge, relativeTo: .caption2).weight(.medium)
}
