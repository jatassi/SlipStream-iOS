import Foundation

/// Resolves a server-relative artwork path (e.g. `/api/v1/metadata/artwork/...`) against the
/// configured server origin. Absolute URLs pass through unchanged; nil/empty input → nil.
/// Returns nil for a path that resolves without a scheme (e.g. a relative path with no `base`),
/// so callers show a placeholder instead of firing a doomed request. The portal returns
/// `posterUrl` as a path relative to the server origin.
public func resolveArtworkURL(_ path: String?, base: URL?) -> URL? {
  guard let path, !path.isEmpty else { return nil }
  guard let resolved = URL(string: path, relativeTo: base)?.absoluteURL else { return nil }
  return resolved.scheme == nil ? nil : resolved
}
