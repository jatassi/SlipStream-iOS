/// The in-library browse surface `LibraryStore` depends on. Backed by `PortalAPIClient`;
/// faked in tests. Both calls hit the token-scoped portal base (`GET /api/v1/requests/library/*`)
/// and return the full library in one payload (no pagination).
public protocol MediaAPI: Sendable {
  func libraryMovies(token: String) async throws -> [PortalMovieSearchResult]
  func librarySeries(token: String) async throws -> [PortalSeriesSearchResult]
}
