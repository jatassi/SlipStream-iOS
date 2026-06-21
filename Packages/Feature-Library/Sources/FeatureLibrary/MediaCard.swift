import DesignSystem
import SlipStreamKit
import SwiftUI

/// One library poster cell: a 2:3 poster with the title and year below it. No
/// availability/state badges — that is F3.4's surface.
struct MediaCard: View {
  let posterURL: URL?
  let module: ModuleType
  let title: String
  let year: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      PosterImage(url: posterURL, module: module)
      Text(title)
        .font(.ssCardTitle)
        .foregroundStyle(DesignTheme.foreground)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
      Text(year.map(String.init) ?? "Unknown year")
        .font(.ssMetadata)
        .foregroundStyle(DesignTheme.mutedForeground)
    }
  }
}
