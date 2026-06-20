/// Mirrors `RequestStatus` in web/src/types/portal.ts (the 8-state request lifecycle).
public enum RequestStatus: String, Codable, Equatable, Sendable, CaseIterable {
  case pending
  case approved
  case denied
  case searching
  case downloading
  case failed
  case available
  case cancelled
}

/// Mirrors `PortalMediaType` in web/src/types/portal.ts.
public enum PortalMediaType: String, Codable, Equatable, Sendable, CaseIterable {
  case movie
  case series
  case season
  case episode
}

/// Mirrors the `status` union of `PortalDownload` in web/src/types/portal.ts.
public enum PortalDownloadStatus: String, Codable, Equatable, Sendable, CaseIterable {
  case queued
  case downloading
  case paused
  case completed
  case failed
  case warning
}

/// Mirrors the `scope` union of `RequestListFilters` in web/src/types/portal.ts.
public enum RequestScope: String, Codable, Equatable, Sendable, CaseIterable {
  case mine
  case all
}
