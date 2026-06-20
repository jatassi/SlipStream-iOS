import Foundation

/// Mirrors `LoginRequest` in web/src/types/portal.ts. The `password` field carries the 4-digit PIN.
public struct LoginRequest: Codable, Equatable, Sendable {
  public let username: String
  public let password: String

  public init(username: String, password: String) {
    self.username = username
    self.password = password
  }
}

/// Mirrors `LoginResponse` in web/src/types/portal.ts.
public struct LoginResponse: Codable, Equatable, Sendable {
  public let token: String
  public let user: PortalUser
  public let isAdmin: Bool

  public init(token: String, user: PortalUser, isAdmin: Bool) {
    self.token = token
    self.user = user
    self.isAdmin = isAdmin
  }
}
