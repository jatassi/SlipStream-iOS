import SwiftUI

/// A centered empty state — icon + title + optional description. Mirrors the web
/// `EmptyState`. Built on `ContentUnavailableView` for the modern idiom.
public struct EmptyStateView: View {
  private let title: String
  private let systemImage: String
  private let description: String?

  public init(title: String, systemImage: String, description: String? = nil) {
    self.title = title
    self.systemImage = systemImage
    self.description = description
  }

  public var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: systemImage)
    } description: {
      if let description {
        Text(description)
      }
    }
  }
}

/// A centered error state with a Retry action, mirroring the web `ErrorState`
/// (`AlertCircle` in the destructive colour + "Try Again").
public struct ErrorStateView: View {
  private let message: String
  private let retry: () -> Void

  public init(message: String, retry: @escaping () -> Void) {
    self.message = message
    self.retry = retry
  }

  public var body: some View {
    ContentUnavailableView {
      Label("Something went wrong", systemImage: "exclamationmark.triangle")
        .foregroundStyle(DesignTheme.destructive)
    } description: {
      Text(message)
    } actions: {
      Button("Try Again", action: retry)
        .buttonStyle(.borderedProminent)
        .tint(DesignTheme.movie)
    }
  }
}

#Preview("States") {
  VStack {
    EmptyStateView(
      title: "No movies available",
      systemImage: "film",
      description: "Movies with files will appear here")
    ErrorStateView(message: "Failed to search") {}
  }
  .background(DesignTheme.background)
}
