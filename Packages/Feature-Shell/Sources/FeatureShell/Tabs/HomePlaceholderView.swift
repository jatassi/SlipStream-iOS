import SwiftUI

/// Placeholder for the Home tab. The request list (F4.2) replaces this.
struct HomePlaceholderView: View {
  var body: some View {
    ContentUnavailableView(
      "Home",
      systemImage: "house",
      description: Text("Your requests will appear here.")
    )
  }
}
