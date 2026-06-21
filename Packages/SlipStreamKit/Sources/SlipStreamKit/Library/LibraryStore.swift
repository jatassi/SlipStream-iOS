import Foundation
import Observation

/// Owns the in-library browse surface: per-tab arrays of movies / series and their
/// load states. Tabs load lazily (a tab fetches on first appearance or after a failure)
/// and are refreshed explicitly (pull / foreground / tab re-selection) — there is no
/// background poll, mirroring the web's staleness-based refetch. The selected tab is
/// persisted through `LibraryTabStore`. Availability is decoded but not surfaced here;
/// per-card state is F3.4's concern.
@MainActor
@Observable
public final class LibraryStore {
  public enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
  }

  public private(set) var movies: [PortalMovieSearchResult] = []
  public private(set) var series: [PortalSeriesSearchResult] = []
  public private(set) var moviesState: LoadState = .idle
  public private(set) var seriesState: LoadState = .idle

  /// The selected sub-tab. Reads/writes persist through `LibraryTabStore`.
  public var selectedTab: LibraryTab {
    didSet { tabStore.setSelectedTab(selectedTab) }
  }

  private let makeMediaAPI: @Sendable (URL) -> MediaAPI
  private let serverConfig: ServerConfigStore
  private let tokenProvider: @MainActor () -> String?
  private let tabStore: LibraryTabStore

  public init(
    makeMediaAPI: @escaping @Sendable (URL) -> MediaAPI,
    serverConfig: ServerConfigStore,
    tokenProvider: @escaping @MainActor () -> String?,
    tabStore: LibraryTabStore
  ) {
    self.makeMediaAPI = makeMediaAPI
    self.serverConfig = serverConfig
    self.tokenProvider = tokenProvider
    self.tabStore = tabStore
    self.selectedTab = tabStore.selectedTab
  }

  /// The configured server origin, for resolving server-relative artwork URLs in the UI.
  public var serverBaseURL: URL? { serverConfig.baseURL }

  public func state(for tab: LibraryTab) -> LoadState {
    switch tab {
    case .movies: moviesState
    case .series: seriesState
    }
  }

  /// Fetch a tab only if it has never loaded or previously failed; a no-op while loading
  /// or already loaded. Call from `.task`/`.onChange(selectedTab)`.
  public func loadIfNeeded(_ tab: LibraryTab) async {
    switch state(for: tab) {
    case .idle, .failed: await load(tab)
    case .loading, .loaded: break
    }
  }

  /// Force a fetch (pull-to-refresh, foreground, retry), regardless of current state.
  public func refresh(_ tab: LibraryTab) async {
    await load(tab)
  }

  private func load(_ tab: LibraryTab) async {
    guard let url = serverConfig.baseURL, let token = tokenProvider() else { return }
    let previous = state(for: tab)
    // Keep already-loaded content visible during a refresh; only show the skeleton on a fresh load.
    if previous != .loaded { setState(.loading, for: tab) }
    let api = makeMediaAPI(url)
    do {
      switch tab {
      case .movies: movies = try await api.libraryMovies(token: token)
      case .series: series = try await api.librarySeries(token: token)
      }
      setState(.loaded, for: tab)
    } catch is CancellationError {
      // Superseded (e.g. tab switch cancelled this task); revert so the tab isn't stranded.
      setState(previous, for: tab)
    } catch let error as APIClientError {
      // URLSession maps cancellation to URLError(.cancelled) → .transport
      if Task.isCancelled {
        setState(previous, for: tab)
      } else {
        setState(.failed(Self.message(for: error)), for: tab)
      }
    } catch {
      if Task.isCancelled {
        setState(previous, for: tab)
      } else {
        setState(.failed(error.localizedDescription), for: tab)
      }
    }
  }

  private func setState(_ state: LoadState, for tab: LibraryTab) {
    switch tab {
    case .movies: moviesState = state
    case .series: seriesState = state
    }
  }

  private static func message(for error: APIClientError) -> String {
    switch error {
    case .http(let status, let message, _): message ?? "Request failed (\(status))."
    case .decoding: "Couldn't read the library response."
    case .transport(let detail): detail
    }
  }
}
