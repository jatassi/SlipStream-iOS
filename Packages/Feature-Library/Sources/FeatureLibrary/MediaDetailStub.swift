import DesignSystem
import SlipStreamKit
import SwiftUI

/// The navigation value for a tapped library poster. A small presentation type
/// (built from a movie or series at tap time) so the `SlipStreamKit` models stay
/// pure JSON mirrors. F3.3 replaces `MediaDetailStubView` with the real detail screen.
struct MediaDetailStub: Hashable, Sendable {
  let mediaId: Int
  let module: ModuleType
  let title: String
  let year: Int?
  let overview: String?
  let posterURL: URL?

  init(movie: PortalMovieSearchResult, baseURL: URL?) {
    mediaId = movie.id
    module = .movie
    title = movie.title
    year = movie.year
    overview = movie.overview
    posterURL = resolveArtworkURL(movie.posterUrl, base: baseURL)
  }

  init(series: PortalSeriesSearchResult, baseURL: URL?) {
    mediaId = series.id
    module = .tv
    title = series.title
    year = series.year
    overview = series.overview
    posterURL = resolveArtworkURL(series.posterUrl, base: baseURL)
  }
}

/// A lightweight placeholder detail rendered from data already in the library
/// payload. F3.3 (rich media detail, second `/metadata` base) replaces this body.
struct MediaDetailStubView: View {
  let stub: MediaDetailStub

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        PosterImage(url: stub.posterURL, module: stub.module)
          .frame(maxWidth: 200)
          .frame(maxWidth: .infinity, alignment: .center)

        Text(stub.title)
          .font(.ssPageTitle)
          .foregroundStyle(DesignTheme.foreground)

        if let year = stub.year {
          Text(String(year))
            .font(.ssBody)
            .foregroundStyle(DesignTheme.mutedForeground)
        }

        if let overview = stub.overview, !overview.isEmpty {
          Text(overview)
            .font(.ssBody)
            .foregroundStyle(DesignTheme.foreground)
        }

        Label("Full details coming soon", systemImage: "hammer")
          .font(.ssMetadata)
          .foregroundStyle(DesignTheme.mutedForeground)
          .padding(.top, 8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
    .navigationTitle(stub.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}
