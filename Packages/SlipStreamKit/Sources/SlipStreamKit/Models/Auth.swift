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

/// Mirrors `SignupRequest` in web/src/types/portal.ts. Redeems an invitation;
/// `token` is the invitation token and `password` carries the new 4-digit PIN.
public struct SignupRequest: Codable, Equatable, Sendable {
  public let token: String
  public let password: String

  public init(token: String, password: String) {
    self.token = token
    self.password = password
  }
}

/// Mirrors `SignupResponse` in web/src/types/portal.ts.
public struct SignupResponse: Codable, Equatable, Sendable {
  public let token: String
  public let user: PortalUser

  public init(token: String, user: PortalUser) {
    self.token = token
    self.user = user
  }
}

/// Mirrors `UpdateProfileRequest` in web/src/types/portal.ts. Both fields are
/// optional; `password` carries a new 4-digit PIN when changing it.
public struct UpdateProfileRequest: Codable, Equatable, Sendable {
  public let username: String?
  public let password: String?

  public init(username: String? = nil, password: String? = nil) {
    self.username = username
    self.password = password
  }
}

/// Mirrors `ValidateInvitationResponse` in web/src/types/portal.ts.
public struct ValidateInvitationResponse: Codable, Equatable, Sendable {
  public let valid: Bool
  public let username: String
  public let expiresAt: String

  public init(valid: Bool, username: String, expiresAt: String) {
    self.valid = valid
    self.username = username
    self.expiresAt = expiresAt
  }
}

/// Mirrors `VerifyPinResponse` in web/src/types/portal.ts.
public struct VerifyPinResponse: Codable, Equatable, Sendable {
  public let valid: Bool

  public init(valid: Bool) {
    self.valid = valid
  }
}
