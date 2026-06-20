import Foundation

/// Mirrors the portal-relevant subset of `GET /api/v1/status` (web/src/types/system.ts).
/// The endpoint is public (no token); unmodeled server fields are ignored on decode.
public struct SystemStatus: Codable, Equatable, Sendable {
    public let portalEnabled: Bool
    public let enabledModules: [String: Bool]?

    public init(portalEnabled: Bool, enabledModules: [String: Bool]?) {
        self.portalEnabled = portalEnabled
        self.enabledModules = enabledModules
    }

    /// Known module types the server reports as enabled, in canonical order
    /// (`ModuleType.allCases`). When the server omits the map entirely, fall back to
    /// all known modules so we never hide a feature on missing data.
    public var enabledModuleTypes: [ModuleType] {
        guard let enabledModules else { return ModuleType.allCases }
        return ModuleType.allCases.filter { enabledModules[$0.rawValue] == true }
    }

    /// Modules this user may request: server-enabled ∩ the user's allowed modules
    /// (`PortalUser.moduleSettings`). Unknown module strings on either side are ignored.
    public func requestableModules(for user: PortalUser) -> [ModuleType] {
        let allowed = Set(user.moduleSettings.compactMap { ModuleType(rawValue: $0.moduleType) })
        return enabledModuleTypes.filter { allowed.contains($0) }
    }

    /// Optimistic stand-in used before the first successful `/status` load:
    /// portal assumed enabled, all known modules assumed enabled.
    public static let optimisticDefault = SystemStatus(portalEnabled: true, enabledModules: nil)
}
