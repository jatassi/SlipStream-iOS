import Foundation

/// The two media sub-tabs of the library browse surface.
public enum LibraryTab: String, CaseIterable, Identifiable, Hashable, Sendable {
  case movies
  case series

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .movies: "Movies"
    case .series: "Series"
    }
  }

  public var systemImage: String {
    switch self {
    case .movies: "film"
    case .series: "tv"
    }
  }
}

/// Non-secret persistence of the last-selected library sub-tab. Defaults to `.movies`.
public protocol LibraryTabStore: Sendable {
  var selectedTab: LibraryTab { get }
  func setSelectedTab(_ tab: LibraryTab)
}

public final class UserDefaultsLibraryTabStore: LibraryTabStore, @unchecked Sendable {
  private let defaults: UserDefaults
  private let key = "slipstream.libraryTab"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public var selectedTab: LibraryTab {
    defaults.string(forKey: key).flatMap(LibraryTab.init(rawValue:)) ?? .movies
  }

  public func setSelectedTab(_ tab: LibraryTab) {
    defaults.set(tab.rawValue, forKey: key)
  }
}
