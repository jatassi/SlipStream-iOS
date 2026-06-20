import SwiftUI

/// Placeholder for the Library tab. The poster grid (F3.1) replaces this.
struct LibraryPlaceholderView: View {
  var body: some View {
    ContentUnavailableView(
      "Library",
      systemImage: "film",
      description: Text("Your in-library movies and series will appear here.")
    )
  }
}
