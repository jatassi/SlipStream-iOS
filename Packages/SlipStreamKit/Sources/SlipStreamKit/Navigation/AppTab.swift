import Foundation

/// The portal's top-level destinations, mirroring the web portal's primary
/// navigation (Requests/Home, Search, Library, Settings). The `allCases` order
/// is the tab-bar / sidebar order.
public enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
  case home
  case search
  case library
  case settings

  public var id: String { rawValue }

  /// Human-readable tab label.
  public var title: String {
    switch self {
    case .home: "Home"
    case .search: "Search"
    case .library: "Library"
    case .settings: "Settings"
    }
  }

  /// SF Symbol name for the tab's icon.
  public var systemImage: String {
    switch self {
    case .home: "house"
    case .search: "magnifyingglass"
    case .library: "film"
    case .settings: "gearshape"
    }
  }
}
