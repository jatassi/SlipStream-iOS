import Foundation

/// Mirrors `UserNotification` in web/src/types/portal.ts (a configured notifier
/// delivery channel). `settings` is schemaless (`Record<string, unknown>`).
public struct UserNotification: Codable, Equatable, Sendable, Identifiable {
  public let id: Int
  public let userId: Int
  public let type: String
  public let name: String
  public let settings: [String: JSONValue]
  public let onAvailable: Bool
  public let onApproved: Bool
  public let onDenied: Bool
  public let enabled: Bool
  public let createdAt: String
  public let updatedAt: String

  public init(
    id: Int,
    userId: Int,
    type: String,
    name: String,
    settings: [String: JSONValue],
    onAvailable: Bool,
    onApproved: Bool,
    onDenied: Bool,
    enabled: Bool,
    createdAt: String,
    updatedAt: String
  ) {
    self.id = id
    self.userId = userId
    self.type = type
    self.name = name
    self.settings = settings
    self.onAvailable = onAvailable
    self.onApproved = onApproved
    self.onDenied = onDenied
    self.enabled = enabled
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

/// Mirrors `CreateUserNotificationInput` in web/src/types/portal.ts (the
/// create/update body for a notifier channel).
public struct CreateUserNotificationInput: Codable, Equatable, Sendable {
  public let type: String
  public let name: String
  public let settings: [String: JSONValue]
  public let onAvailable: Bool
  public let onApproved: Bool
  public let onDenied: Bool
  public let enabled: Bool

  public init(
    type: String,
    name: String,
    settings: [String: JSONValue],
    onAvailable: Bool,
    onApproved: Bool,
    onDenied: Bool,
    enabled: Bool
  ) {
    self.type = type
    self.name = name
    self.settings = settings
    self.onAvailable = onAvailable
    self.onApproved = onApproved
    self.onDenied = onDenied
    self.enabled = enabled
  }
}
