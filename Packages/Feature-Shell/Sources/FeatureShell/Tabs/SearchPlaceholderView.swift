import SwiftUI

/// Placeholder for the Search tab. Title search (F3.2) replaces this. The
/// `.searchable` field establishes the search entry point now; results arrive
/// with F3.2.
struct SearchPlaceholderView: View {
  @State private var query = ""

  var body: some View {
    ContentUnavailableView(
      "Search",
      systemImage: "magnifyingglass",
      description: Text("Search movies and series.")
    )
    .searchable(text: $query, prompt: "Search movies and series")
  }
}
