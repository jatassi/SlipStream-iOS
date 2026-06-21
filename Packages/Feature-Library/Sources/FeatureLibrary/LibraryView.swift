import DesignSystem
import SlipStreamKit
import SwiftUI

/// The Library tab: Movies / Series sub-tabs over an adaptive poster grid of the
/// server's in-library titles. Tabs load lazily and refresh on appear / foreground /
/// re-selection / pull — no background poll. Reads the shared `LibraryStore` and
/// `PosterSizePreference` from the environment.
public struct LibraryView: View {
  @Environment(LibraryStore.self) private var store
  @Environment(PosterSizePreference.self) private var posterSize
  @Environment(\.scenePhase) private var scenePhase
  @State private var showingSizeControl = false

  public init() {}

  public var body: some View {
    @Bindable var store = store
    VStack(spacing: 0) {
      Picker("Library section", selection: $store.selectedTab) {
        ForEach(LibraryTab.allCases) { tab in
          Text(tab.title).tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)
      .padding(.bottom, 8)

      content
    }
    .refreshable { await store.refresh(store.selectedTab) }
    .navigationDestination(for: MediaDetailStub.self) { stub in
      MediaDetailStubView(stub: stub)
    }
    .task(id: store.selectedTab) { await store.loadIfNeeded(store.selectedTab) }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await store.refresh(store.selectedTab) } }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showingSizeControl = true
        } label: {
          Image(systemName: "rectangle.grid.3x2")
        }
        .accessibilityLabel("Poster size")
        .popover(isPresented: $showingSizeControl) {
          PosterSizeSlider(preference: posterSize)
            .frame(minWidth: 260)
            .padding()
            .presentationCompactAdaptation(.popover)
        }
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch store.state(for: store.selectedTab) {
    case .idle, .loading:
      ScrollView {
        PosterGridSkeleton(minItemWidth: posterSize.size).padding()
      }
    case .failed(let message):
      ErrorStateView(message: message) {
        Task { await store.refresh(store.selectedTab) }
      }
    case .loaded:
      loadedContent
    }
  }

  @ViewBuilder
  private var loadedContent: some View {
    switch store.selectedTab {
    case .movies:
      grid(
        items: store.movies,
        emptyTitle: "No movies available",
        emptyDescription: "Movies with files will appear here",
        card: {
          MediaCard(
            posterURL: posterURL($0.posterUrl), module: .movie, title: $0.title, year: $0.year)
        },
        stub: { MediaDetailStub(movie: $0, baseURL: store.serverBaseURL) })
    case .series:
      grid(
        items: store.series,
        emptyTitle: "No series available",
        emptyDescription: "Series with files will appear here",
        card: {
          MediaCard(posterURL: posterURL($0.posterUrl), module: .tv, title: $0.title, year: $0.year)
        },
        stub: { MediaDetailStub(series: $0, baseURL: store.serverBaseURL) })
    }
  }

  @ViewBuilder
  private func grid<Item: Identifiable>(
    items: [Item],
    emptyTitle: String,
    emptyDescription: String,
    card: @escaping (Item) -> MediaCard,
    stub: @escaping (Item) -> MediaDetailStub
  ) -> some View {
    if items.isEmpty {
      EmptyStateView(
        title: emptyTitle,
        systemImage: store.selectedTab.systemImage,
        description: emptyDescription)
    } else {
      ScrollView {
        PosterGrid(items: items, minItemWidth: posterSize.size) { item in
          NavigationLink(value: stub(item)) {
            card(item)
          }
          .buttonStyle(.plain)
        }
        .padding()
      }
    }
  }

  private func posterURL(_ string: String?) -> URL? {
    resolveArtworkURL(string, base: store.serverBaseURL)
  }
}
