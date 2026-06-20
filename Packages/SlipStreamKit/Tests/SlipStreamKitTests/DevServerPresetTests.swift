import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct DevServerPresetTests {
  @Test func localhostPresetTargetsLoopbackDevPort() {
    #expect(DevServerPreset.localhost.urlString == "http://localhost:8080")
    let host = URL(string: DevServerPreset.localhost.urlString)!.host!
    #expect(ServerURLValidator.isLocalHost(host))
  }

  @Test func productionPresetIsHTTPS() {
    #expect(DevServerPreset.production.urlString == "https://slipstream.atassi.org")
  }

  @Test func macOnLANUsesDotLocalOverrideWhenPresent() {
    let cfg = DevLaunchConfig(environment: ["SLIPSTREAM_BASE_URL": "http://jacks-mac.local:8080"])
    #expect(DevServerPreset.macOnLAN(from: cfg).urlString == "http://jacks-mac.local:8080")
  }

  @Test func macOnLANFallsBackToEditablePlaceholderOtherwise() {
    let cfg = DevLaunchConfig(environment: [:])
    #expect(DevServerPreset.macOnLAN(from: cfg).urlString == "http://your-mac.local:8080")
    // A non-.local override (e.g. localhost) does not hijack the LAN preset.
    let local = DevLaunchConfig(environment: ["SLIPSTREAM_BASE_URL": "http://localhost:8080"])
    #expect(DevServerPreset.macOnLAN(from: local).urlString == "http://your-mac.local:8080")
  }

  @Test func macOnLANHonorsUppercaseDotLocalOverride() {
    let cfg = DevLaunchConfig(environment: ["SLIPSTREAM_BASE_URL": "http://Jacks-Mac.LOCAL:8080"])
    #expect(DevServerPreset.macOnLAN(from: cfg).urlString == "http://Jacks-Mac.LOCAL:8080")
  }

  @Test func allListsThreePresetsInOrder() {
    let presets = DevServerPreset.all(config: DevLaunchConfig(environment: [:]))
    #expect(presets.map(\.id) == ["localhost", "lan", "production"])
  }
}
