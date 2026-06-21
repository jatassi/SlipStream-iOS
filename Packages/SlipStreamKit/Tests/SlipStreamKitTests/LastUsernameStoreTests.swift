import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct LastUsernameStoreTests {
  /// A fresh, isolated `UserDefaults` suite per test so concurrently-run cases
  /// can't clobber one another's keys.
  private func makeStore(_ suite: String) -> UserDefaultsLastUsernameStore {
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return UserDefaultsLastUsernameStore(defaults: defaults)
  }

  @Test func emptyStoreReturnsNil() {
    let suite = "test.slipstream.lastUsername.empty"
    let store = makeStore(suite)
    #expect(store.lastUsername == nil)
    UserDefaults().removePersistentDomain(forName: suite)
  }

  @Test func setThenLoadRoundTrips() {
    let suite = "test.slipstream.lastUsername.roundtrip"
    let store = makeStore(suite)
    store.setLastUsername("jack")
    #expect(store.lastUsername == "jack")
    UserDefaults().removePersistentDomain(forName: suite)
  }

  @Test func setOverwritesPreviousUsername() {
    let suite = "test.slipstream.lastUsername.overwrite"
    let store = makeStore(suite)
    store.setLastUsername("jack")
    store.setLastUsername("jill")
    #expect(store.lastUsername == "jill")
    UserDefaults().removePersistentDomain(forName: suite)
  }
}
