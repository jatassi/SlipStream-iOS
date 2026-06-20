import SlipStreamKit
import SwiftUI

/// The signed-in app shell: an adaptive `TabView` that renders a tab bar on
/// iPhone (compact) and a sidebar on iPad / Mac (regular) via `.sidebarAdaptable`
/// — one layer for all three platforms. Each tab hosts its own `NavigationStack`
/// (so features can push detail screens) and reserves the global downloads-strip
/// slot just below the navigation bar.
public struct AppShellView: View {
  @Environment(NavigationModel.self) private var nav

  public init() {}

  public var body: some View {
    @Bindable var nav = nav
    TabView(selection: $nav.selectedTab) {
      Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
        tab(.home) { HomePlaceholderView() }
      }
      Tab(AppTab.search.title, systemImage: AppTab.search.systemImage, value: AppTab.search) {
        tab(.search) { SearchPlaceholderView() }
      }
      Tab(AppTab.library.title, systemImage: AppTab.library.systemImage, value: AppTab.library) {
        tab(.library) { LibraryPlaceholderView() }
      }
      Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: AppTab.settings) {
        tab(.settings) { SettingsPlaceholderView() }
      }
    }
    .tabViewStyle(.sidebarAdaptable)
  }

  /// Wraps a tab's content in its own navigation stack and reserves the
  /// downloads-strip slot below the navigation bar.
  @ViewBuilder
  private func tab<Content: View>(
    _ tab: AppTab,
    @ViewBuilder content: () -> Content
  ) -> some View {
    NavigationStack {
      content()
        .navigationTitle(tab.title)
        .safeAreaInset(edge: .top, spacing: 0) { DownloadsStrip() }
    }
  }
}
