import Foundation

/// A named, one-tap server target surfaced in the Debug sign-in picker.
public struct DevServerPreset: Identifiable, Sendable, Equatable {
  public let id: String
  public let name: String
  public let urlString: String

  public init(id: String, name: String, urlString: String) {
    self.id = id
    self.name = name
    self.urlString = urlString
  }

  /// Simulator and Mac (Designed for iPad) reach the dev server over loopback.
  public static let localhost = DevServerPreset(
    id: "localhost", name: "Localhost (sim/Mac)", urlString: "http://localhost:8080")

  /// The real server.
  public static let production = DevServerPreset(
    id: "production", name: "Production", urlString: "https://slipstream.atassi.org")

  /// "Mac on LAN" target for a physical device. A phone cannot reach `localhost`, so it
  /// addresses the Mac by its Bonjour `.local` name (stable across DHCP, and covered by
  /// `NSAllowsLocalNetworking`). Uses the `SLIPSTREAM_BASE_URL` launch override when that
  /// points at a `.local` host; otherwise an obviously-editable placeholder the tester
  /// replaces with their Mac's name.
  public static func macOnLAN(from config: DevLaunchConfig) -> DevServerPreset {
    let lanURL: String
    if let override = config.baseURLOverride,
      override.host?.lowercased().hasSuffix(".local") == true
    {
      lanURL = override.absoluteString
    } else {
      lanURL = "http://your-mac.local:8080"
    }
    return DevServerPreset(id: "lan", name: "Mac on LAN (device)", urlString: lanURL)
  }

  /// All presets, in display order.
  public static func all(config: DevLaunchConfig) -> [DevServerPreset] {
    [.localhost, macOnLAN(from: config), .production]
  }
}
