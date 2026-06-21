import SlipStreamKit
import SwiftUI

/// A DEBUG-only living catalog of DesignSystem components, surfaced via a floating
/// button → sheet in `RootView` so each piece is verifiable on the simulator
/// without signing in. Tasks 5–11 replace the `EmptyView()` stubs with real content.
public struct DesignSystemGalleryView: View {
  // Read the single shared preference the app injects (`SlipStreamApp` →
  // `.environment(posterSize)`), so the gallery slider drives the same instance
  // the real media surfaces use — not a private copy. Present pre-auth too,
  // since the injection lives at the app root.
  @Environment(PosterSizePreference.self) private var posterSize

  public init() {}

  public var body: some View {
    List {
      themeSection
      typographySection
      posterImageSection
      posterGridSection
      skeletonSection
      statesSection
      brandSection
      statusSection
    }
    .navigationTitle("Design System")
    .listStyle(.insetGrouped)
  }

  @ViewBuilder private var themeSection: some View {
    Section("Theme") {
      let swatches: [(String, Color)] = [
        ("background", DesignTheme.background), ("surface", DesignTheme.surface),
        ("foreground", DesignTheme.foreground), ("muted", DesignTheme.muted),
        ("mutedFg", DesignTheme.mutedForeground), ("border", DesignTheme.border),
        ("destructive", DesignTheme.destructive), ("movie", DesignTheme.movie),
        ("tv", DesignTheme.tv),
      ]
      ForEach(swatches, id: \.0) { name, color in
        HStack {
          RoundedRectangle(cornerRadius: RadiusScale.small)
            .fill(color)
            .frame(width: 44, height: 28)
            .overlay(RoundedRectangle(cornerRadius: RadiusScale.small).stroke(DesignTheme.border))
          Text(name)
        }
      }
      RoundedRectangle(cornerRadius: RadiusScale.base)
        .fill(DesignTheme.mediaGradient)
        .frame(height: 28)
        .overlay(Text("media gradient").font(.caption).foregroundStyle(.white))
    }
  }

  @ViewBuilder private var typographySection: some View {
    Section("Typography (Inter)") {
      Text("Page Title").font(.ssPageTitle)
      Text("Section Heading").font(.ssSection)
      Text("Card Title").font(.ssCardTitle)
      Text("Body copy — the quick brown fox.").font(.ssBody)
      Text("Metadata · 2026").font(.ssMetadata).foregroundStyle(DesignTheme.mutedForeground)
      Text("BADGE").font(.ssBadge)
    }
  }
  @ViewBuilder private var posterImageSection: some View {
    Section("PosterImage") {
      HStack(spacing: 12) {
        PosterImage(
          url: URL(string: "https://image.tmdb.org/t/p/w342/8IB2e4r4oVhHnANbnm7O3Tj6tF8.jpg"),
          module: .movie)
        PosterImage(url: nil, module: .movie)
        PosterImage(url: nil, module: .tv)
      }
      .frame(height: 180)
      PosterImage(url: nil, module: .movie)
        .frame(height: 150)
        .glow(.movie)
    }
  }
  @ViewBuilder private var posterGridSection: some View {
    Section("PosterGrid + PosterSizeSlider") {
      PosterSizeSlider(preference: posterSize)
      PosterGrid(items: GalleryPoster.samples, minItemWidth: posterSize.size) { poster in
        PosterImage(url: nil, module: poster.module)
      }
    }
  }
  @ViewBuilder private var skeletonSection: some View {
    Section("Skeletons") {
      PosterGridSkeleton(count: 6)
      SearchLoadingSkeleton(count: 6)
    }
  }
  @ViewBuilder private var statesSection: some View {
    Section("Empty / Error states") {
      EmptyStateView(
        title: "No movies available",
        systemImage: "film",
        description: "Movies with files will appear here")
      ErrorStateView(message: "Failed to search") {}
    }
  }
  @ViewBuilder private var brandSection: some View {
    Section("Brand") {
      HStack(spacing: 12) {
        SlipStreamLogoMark()
        SlipStreamWordmark()
      }
    }
  }
  @ViewBuilder private var statusSection: some View {
    Section("Status palette") {
      ForEach(RequestStatus.allCases, id: \.self) { status in
        StatusBadge(status)
      }
    }
  }
}

/// Throwaway sample data for the gallery's grid section.
private struct GalleryPoster: Identifiable {
  let id: Int
  let module: ModuleType

  static let samples: [GalleryPoster] = (0..<8).map {
    GalleryPoster(id: $0, module: $0.isMultiple(of: 2) ? .movie : .tv)
  }
}
