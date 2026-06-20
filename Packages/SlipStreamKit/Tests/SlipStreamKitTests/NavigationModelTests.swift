import Testing

@testable import SlipStreamKit

@Suite struct AppTabTests {
  @Test func allCasesAreHomeSearchLibrarySettingsInOrder() {
    #expect(AppTab.allCases == [.home, .search, .library, .settings])
  }

  @Test func eachTabHasANonEmptyTitleAndSymbol() {
    #expect(AppTab.home.title == "Home")
    #expect(AppTab.search.title == "Search")
    #expect(AppTab.library.title == "Library")
    #expect(AppTab.settings.title == "Settings")
    for tab in AppTab.allCases {
      #expect(!tab.title.isEmpty)
      #expect(!tab.systemImage.isEmpty)
      #expect(tab.id == tab.rawValue)
    }
  }
}

@MainActor
@Suite struct NavigationModelTests {
  @Test func defaultsToHome() {
    let nav = NavigationModel()
    #expect(nav.selectedTab == .home)
  }

  @Test func initWithExplicitTabIsHonored() {
    let nav = NavigationModel(selectedTab: .settings)
    #expect(nav.selectedTab == .settings)
  }

  @Test func selectChangesTheActiveTab() {
    let nav = NavigationModel()
    nav.select(.library)
    #expect(nav.selectedTab == .library)
  }
}
