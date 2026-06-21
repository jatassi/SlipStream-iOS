import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct LibraryTabStoreTests {
  private func makeDefaults() -> UserDefaults {
    let suite = "test.library.tab.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }

  @Test func defaultsToMoviesWhenUnset() {
    let store = UserDefaultsLibraryTabStore(defaults: makeDefaults())
    #expect(store.selectedTab == .movies)
  }

  @Test func persistsAndRestoresSelectedTab() {
    let defaults = makeDefaults()
    let store = UserDefaultsLibraryTabStore(defaults: defaults)
    store.setSelectedTab(.series)
    #expect(store.selectedTab == .series)
    // A fresh instance over the same defaults restores it.
    let restored = UserDefaultsLibraryTabStore(defaults: defaults)
    #expect(restored.selectedTab == .series)
  }

  @Test func fallsBackToMoviesOnUnrecognisedValue() {
    let defaults = makeDefaults()
    defaults.set("garbage", forKey: "slipstream.libraryTab")
    let store = UserDefaultsLibraryTabStore(defaults: defaults)
    #expect(store.selectedTab == .movies)
  }

  @Test func tabTitlesAndIds() {
    #expect(LibraryTab.movies.title == "Movies")
    #expect(LibraryTab.series.title == "Series")
    #expect(LibraryTab.movies.id == "movies")
    #expect(LibraryTab.series.id == "series")
    #expect(LibraryTab.allCases == [.movies, .series])
    #expect(LibraryTab.movies.systemImage == "film")
    #expect(LibraryTab.series.systemImage == "tv")
  }
}
