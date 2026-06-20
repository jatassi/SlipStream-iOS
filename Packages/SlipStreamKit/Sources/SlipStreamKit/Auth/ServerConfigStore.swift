import Foundation

/// Non-secret persistence of the server's base URL (the HTTPS reverse-proxy origin).
public protocol ServerConfigStore: Sendable {
    var baseURL: URL? { get }
    func setBaseURL(_ url: URL)
}

public final class UserDefaultsServerConfigStore: ServerConfigStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "slipstream.serverBaseURL"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var baseURL: URL? {
        defaults.string(forKey: key).flatMap(URL.init(string:))
    }

    public func setBaseURL(_ url: URL) {
        defaults.set(url.absoluteString, forKey: key)
    }
}
