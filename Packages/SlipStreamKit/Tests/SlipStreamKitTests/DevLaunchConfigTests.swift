import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct DevLaunchConfigTests {
  @Test func parsesAllValues() {
    let cfg = DevLaunchConfig(environment: [
      "SLIPSTREAM_BASE_URL": "http://localhost:8080",
      "SLIPSTREAM_DEV_USERNAME": "tester",
      "SLIPSTREAM_DEV_PIN": "1234",
    ])
    #expect(cfg.baseURLOverride == URL(string: "http://localhost:8080"))
    #expect(cfg.devUsername == "tester")
    #expect(cfg.devPIN == "1234")
  }

  @Test func emptyEnvironmentYieldsNils() {
    let cfg = DevLaunchConfig(environment: [:])
    #expect(cfg.baseURLOverride == nil)
    #expect(cfg.devUsername == nil)
    #expect(cfg.devPIN == nil)
  }

  @Test func blankStringsAreTreatedAsAbsent() {
    let cfg = DevLaunchConfig(environment: [
      "SLIPSTREAM_BASE_URL": "",
      "SLIPSTREAM_DEV_USERNAME": "",
      "SLIPSTREAM_DEV_PIN": "",
    ])
    #expect(cfg.baseURLOverride == nil)
    #expect(cfg.devUsername == nil)
    #expect(cfg.devPIN == nil)
  }

  @Test func malformedBaseURLIsNil() {
    let cfg = DevLaunchConfig(environment: ["SLIPSTREAM_BASE_URL": "ht tp://not a url"])
    #expect(cfg.baseURLOverride == nil)
  }
}
