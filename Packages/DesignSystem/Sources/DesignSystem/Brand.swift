import SwiftUI

/// The SlipStream logo mark — a rounded square filled with the media gradient and
/// a white "SS" monogram, with a soft glow (web `bg-media-gradient glow-media-sm`).
public struct SlipStreamLogoMark: View {
  private let size: CGFloat

  public init(size: CGFloat = 40) {
    self.size = size
  }

  public var body: some View {
    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
      .fill(DesignTheme.mediaGradient)
      .frame(width: size, height: size)
      .overlay {
        Text("SS")
          .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
      }
      .glow(DesignTheme.movie, radius: size * 0.18)
  }
}

/// The "SlipStream" wordmark with the media gradient as its fill
/// (web `text-media-gradient`).
public struct SlipStreamWordmark: View {
  public init() {}

  public var body: some View {
    Text("SlipStream")
      .font(.ssSection)
      .foregroundStyle(DesignTheme.mediaGradient)
  }
}

#Preview("Brand") {
  HStack(spacing: 12) {
    SlipStreamLogoMark()
    SlipStreamWordmark()
  }
  .padding()
  .background(DesignTheme.background)
}
