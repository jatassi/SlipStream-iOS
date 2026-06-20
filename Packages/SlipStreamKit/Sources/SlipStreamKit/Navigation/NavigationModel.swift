import Foundation
import Observation

/// App-wide navigation state for the signed-in shell. Owns the selected
/// top-level tab so features can switch tabs programmatically (e.g. a request
/// notification deep-links to Home). Detail screens are pushed onto each tab's
/// own `NavigationStack` by their owning features — this model holds only the
/// top-level selection.
@MainActor
@Observable
public final class NavigationModel {
  public var selectedTab: AppTab

  public init(selectedTab: AppTab = .home) {
    self.selectedTab = selectedTab
  }

  /// Switch the active top-level tab.
  public func select(_ tab: AppTab) {
    selectedTab = tab
  }
}
