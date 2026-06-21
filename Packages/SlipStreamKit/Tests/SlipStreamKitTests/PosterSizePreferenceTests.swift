import CoreGraphics
import Foundation
import Testing

@testable import SlipStreamKit

@MainActor
@Suite struct PosterSizePreferenceTests {
  @Test func usesDefaultWhenStoreEmpty() {
    let pref = PosterSizePreference(store: FakePosterSizeStore(stored: nil))
    #expect(pref.size == PosterGridMetrics.defaultSize)
  }

  @Test func loadsPersistedValueClamped() {
    let pref = PosterSizePreference(store: FakePosterSizeStore(stored: 999))
    #expect(pref.size == PosterGridMetrics.maxSize)
  }

  @Test func setSizeClampsWithinRangeAndPersists() {
    let store = FakePosterSizeStore()
    let pref = PosterSizePreference(store: store)
    pref.setSize(220)
    #expect(pref.size == 220)
    #expect(store.stored == 220)
    #expect(store.saveCount == 1)
  }

  @Test func setSizeAboveMaxClampsToMaxAndPersistsClamped() {
    let store = FakePosterSizeStore()
    let pref = PosterSizePreference(store: store)
    pref.setSize(400)
    #expect(pref.size == PosterGridMetrics.maxSize)
    #expect(store.stored == PosterGridMetrics.maxSize)
  }

  @Test func userDefaultsStoreRoundTrips() {
    let suite = "test.slipstream.posterSize"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    let store = UserDefaultsPosterSizeStore(defaults: defaults)
    #expect(store.loadPosterSize() == nil)
    store.savePosterSize(180)
    #expect(store.loadPosterSize() == 180)
    defaults.removePersistentDomain(forName: suite)
  }
}
