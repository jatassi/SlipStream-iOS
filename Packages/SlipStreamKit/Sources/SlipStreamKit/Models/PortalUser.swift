import Foundation

/// Mirrors `UserModuleSetting` in web/src/types/portal.ts.
public struct UserModuleSetting: Codable, Equatable, Sendable {
    public let moduleType: String
    public let qualityProfileId: Int?

    public init(moduleType: String, qualityProfileId: Int?) {
        self.moduleType = moduleType
        self.qualityProfileId = qualityProfileId
    }
}

/// Mirrors `PortalUser` in web/src/types/portal.ts.
public struct PortalUser: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let username: String
    public let moduleSettings: [UserModuleSetting]
    public let autoApprove: Bool
    public let enabled: Bool
    public let isAdmin: Bool
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: Int,
        username: String,
        moduleSettings: [UserModuleSetting],
        autoApprove: Bool,
        enabled: Bool,
        isAdmin: Bool,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.username = username
        self.moduleSettings = moduleSettings
        self.autoApprove = autoApprove
        self.enabled = enabled
        self.isAdmin = isAdmin
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
