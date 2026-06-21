import CoreGraphics

/// Corner-radius scale mirroring the web `--radius: 0.45rem` token
/// (`web/src/index.css`). `base` ≈ Tailwind `rounded-lg`; badges use `pill`.
public enum RadiusScale {
  public static let small: CGFloat = 4
  public static let base: CGFloat = 7
  public static let pill: CGFloat = 999
}

/// Type-ramp point sizes mirroring the web portal's `text-*` usage: page title
/// (`text-2xl`), section (`text-xl`), card title (`text-base`), body (`text-sm`),
/// metadata (`text-xs`), badge (`text-[10px]`).
public enum TypeScale {
  public static let pageTitle: CGFloat = 24
  public static let section: CGFloat = 20
  public static let cardTitle: CGFloat = 16
  public static let body: CGFloat = 14
  public static let metadata: CGFloat = 12
  public static let badge: CGFloat = 10
}
