import SwiftUI

/// Repeating opacity pulse — the iOS analogue of Tailwind's `animate-pulse`,
/// used for the muted placeholders the web renders with `bg-muted animate-pulse`.
private struct PulseModifier: ViewModifier {
  @State private var isPulsing = false

  func body(content: Content) -> some View {
    content
      .opacity(isPulsing ? 0.35 : 0.85)
      .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
      .onAppear { isPulsing = true }
  }
}

/// A light sweep across the view — the iOS analogue of the web
/// `animate-skeleton-shimmer` gradient that slides over each `Skeleton`.
private struct ShimmerModifier: ViewModifier {
  @State private var phase: CGFloat = -1

  func body(content: Content) -> some View {
    content
      .overlay {
        GeometryReader { geo in
          LinearGradient(
            colors: [.clear, .white.opacity(0.25), .clear],
            startPoint: .leading, endPoint: .trailing
          )
          .frame(width: geo.size.width)
          .offset(x: phase * geo.size.width * 2)
        }
      }
      .mask(content)
      .onAppear {
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
          phase = 1
        }
      }
  }
}

extension View {
  /// Apply the standard loading-placeholder pulse.
  func pulsing() -> some View { modifier(PulseModifier()) }
  /// Apply the standard skeleton shimmer sweep.
  func shimmering() -> some View { modifier(ShimmerModifier()) }
}
