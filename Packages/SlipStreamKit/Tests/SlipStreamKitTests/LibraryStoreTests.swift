import Foundation
import Testing

@testable import SlipStreamKit

@MainActor
@Suite struct LibraryStoreTests {
  let serverURL = URL(string: "https://slipstream.example.com")!

  private func makeStore(
    api: FakeMediaAPI,
    config: FakeServerConfigStore? = nil,
    token: String? = "tok",
    tabStore: FakeLibraryTabStore = FakeLibraryTabStore()
  ) -> LibraryStore {
    LibraryStore(
      makeMediaAPI: { _ in api },
      serverConfig: config ?? FakeServerConfigStore(url: serverURL),
      tokenProvider: { token },
      tabStore: tabStore
    )
  }

  @Test func loadIfNeededPopulatesMoviesAndMarksLoaded() async {
    let api = FakeMediaAPI(onMovies: { _ in [sampleMovie(), sampleMovie(id: 9, title: "Heat")] })
    let store = makeStore(api: api)

    await store.loadIfNeeded(.movies)

    #expect(store.movies.count == 2)
    #expect(store.state(for: .movies) == .loaded)
  }

  @Test func emptyPayloadMarksLoadedWithNoItems() async {
    let store = makeStore(api: FakeMediaAPI(onMovies: { _ in [] }))
    await store.loadIfNeeded(.movies)
    #expect(store.movies.isEmpty)
    #expect(store.state(for: .movies) == .loaded)
  }

  @Test func failureMarksFailedWithMessage() async {
    let api = FakeMediaAPI(onMovies: { _ in
      throw APIClientError.http(status: 500, message: "boom", error: nil)
    })
    let store = makeStore(api: api)

    await store.loadIfNeeded(.movies)

    #expect(store.state(for: .movies) == .failed("boom"))
    #expect(store.movies.isEmpty)
  }

  @Test func loadIfNeededIsLazyPerTab() async {
    let api = FakeMediaAPI(
      onMovies: { _ in [sampleMovie()] },
      onSeries: { _ in
        Issue.record("series must not be fetched when only movies is requested")
        return []
      })
    let store = makeStore(api: api)
    await store.loadIfNeeded(.movies)
    #expect(store.state(for: .series) == .idle)
  }

  @Test func loadIfNeededSkipsWhenAlreadyLoaded() async {
    let counter = CallCounter()
    let api = FakeMediaAPI(onMovies: { _ in
      counter.increment()
      return [sampleMovie()]
    })
    let store = makeStore(api: api)

    await store.loadIfNeeded(.movies)
    await store.loadIfNeeded(.movies)

    #expect(counter.count == 1)
  }

  @Test func refreshReFetchesEvenWhenLoaded() async {
    let counter = CallCounter()
    let api = FakeMediaAPI(onMovies: { _ in
      counter.increment()
      return [sampleMovie()]
    })
    let store = makeStore(api: api)

    await store.loadIfNeeded(.movies)
    await store.refresh(.movies)

    #expect(counter.count == 2)
  }

  @Test func loadIfNeededRetriesAfterFailure() async {
    let counter = CallCounter()
    let api = FakeMediaAPI(onMovies: { _ in
      counter.increment()
      throw APIClientError.transport("offline")
    })
    let store = makeStore(api: api)

    await store.loadIfNeeded(.movies)  // fails
    #expect(store.state(for: .movies) == .failed("offline"))
    await store.loadIfNeeded(.movies)  // failed state is retryable, so this fetches again

    #expect(counter.count == 2)
  }

  @Test func cancelledLoadRevertsAndStaysRetryable() async {
    let counter = CallCounter()
    let api = FakeMediaAPI(onMovies: { _ in
      counter.increment()
      if counter.count == 1 { throw CancellationError() }
      return [sampleMovie()]
    })
    let store = makeStore(api: api)

    await store.loadIfNeeded(.movies)
    // After cancellation, state must revert to .idle (not .failed, not .loading).
    #expect(store.state(for: .movies) == .idle)

    // Tab is not stranded — a second load must succeed.
    await store.loadIfNeeded(.movies)
    #expect(store.state(for: .movies) == .loaded)
    #expect(store.movies.count == 1)
    #expect(counter.count == 2)
  }

  @Test func selectedTabSetterPersists() {
    let tabStore = FakeLibraryTabStore(tab: .movies)
    let store = makeStore(api: FakeMediaAPI(), tabStore: tabStore)

    store.selectedTab = .series

    #expect(store.selectedTab == .series)
    #expect(tabStore.selectedTab == .series)
    #expect(tabStore.setCount == 1)
  }

  @Test func selectedTabInitialisesFromStore() {
    let store = makeStore(api: FakeMediaAPI(), tabStore: FakeLibraryTabStore(tab: .series))
    #expect(store.selectedTab == .series)
  }

  @Test func loadIsNoOpWithoutToken() async {
    let api = FakeMediaAPI(onMovies: { _ in
      Issue.record("must not fetch without a token")
      return []
    })
    let store = makeStore(api: api, token: nil)
    await store.loadIfNeeded(.movies)
    #expect(store.state(for: .movies) == .idle)
  }

  @Test func loadIsNoOpWithoutBaseURL() async {
    let api = FakeMediaAPI(onMovies: { _ in
      Issue.record("must not fetch without a base URL")
      return []
    })
    let store = makeStore(api: api, config: FakeServerConfigStore(url: nil))
    await store.loadIfNeeded(.movies)
    #expect(store.state(for: .movies) == .idle)
  }
}
