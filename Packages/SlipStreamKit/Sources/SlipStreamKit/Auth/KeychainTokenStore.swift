import Foundation
import LocalAuthentication
import Security

public enum KeychainError: Error, Equatable {
  case accessControl
  case userCanceled
  case unhandled(OSStatus)
}

/// Stores the JWT in the Keychain behind `.userPresence` (Face ID / Touch ID / passcode),
/// accessible only when the device is unlocked, and never synced off-device.
public struct KeychainTokenStore: TokenStore {
  private let service: String
  private let account: String

  public init(
    service: String = "dev.jatassi.slipstream.portal-jwt",
    account: String = "portal-token"
  ) {
    self.service = service
    self.account = account
  }

  public func save(_ token: String) throws {
    // Replace any existing item.
    SecItemDelete(
      [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
      ] as CFDictionary)

    // Pass nil for the error out-param: every failure collapses to
    // .accessControl, and capturing the CFError would leak it (it is never read).
    guard
      let access = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        .userPresence,
        nil
      )
    else {
      throw KeychainError.accessControl
    }

    let status = SecItemAdd(
      [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecValueData as String: Data(token.utf8),
        kSecAttrAccessControl as String: access,
      ] as CFDictionary, nil)

    guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
  }

  public func load() async throws -> String? {
    // The biometric prompt is presented by the system; run the (blocking) Keychain read
    // off the main actor so the UI stays responsive.
    let keychainService = service
    let keychainAccount = account
    return try await Task.detached(priority: .userInitiated) {
      let context = LAContext()
      context.localizedReason = "Unlock SlipStream"

      var item: CFTypeRef?
      let status = SecItemCopyMatching(
        [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrService as String: keychainService,
          kSecAttrAccount as String: keychainAccount,
          kSecReturnData as String: true,
          kSecMatchLimit as String: kSecMatchLimitOne,
          kSecUseAuthenticationContext as String: context,
        ] as CFDictionary, &item)

      switch status {
      case errSecSuccess:
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
      case errSecItemNotFound:
        return nil
      case errSecUserCanceled:
        throw KeychainError.userCanceled
      default:
        throw KeychainError.unhandled(status)
      }
    }.value
  }

  public func delete() throws {
    let status = SecItemDelete(
      [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
      ] as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.unhandled(status)
    }
  }
}
