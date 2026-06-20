import Foundation
import Observation

/// Owns system/module discovery: fetches the public `GET /api/v1/status`, exposes
/// `portalEnabled` and the enabled module types, and computes which modules a given
/// user may request. Discovery is non-fatal — before the first successful load (or
/// after a failure) it serves optimistic defaults so the UI never hides a feature.
@MainActor
@Observable
public final class SystemStore {
  public private(set) var status: SystemStatus?
  public private(set) var lastError: APIClientError?

  private let makeSystemAPI: @Sendable (URL) -> SystemAPI
  private let serverConfig: ServerConfigStore

  public init(
    makeSystemAPI: @escaping @Sendable (URL) -> SystemAPI,
    serverConfig: ServerConfigStore
  ) {
    self.makeSystemAPI = makeSystemAPI
    self.serverConfig = serverConfig
  }

  /// The loaded status, or an optimistic stand-in (portal on, all modules enabled)
  /// before the first successful load.
  public var effectiveStatus: SystemStatus { status ?? .optimisticDefault }
  public var portalEnabled: Bool { effectiveStatus.portalEnabled }
  public var enabledModuleTypes: [ModuleType] { effectiveStatus.enabledModuleTypes }

  /// Modules this user may request: server-enabled ∩ the user's allowed modules.
  public func requestableModules(for user: PortalUser) -> [ModuleType] {
    effectiveStatus.requestableModules(for: user)
  }

  /// Fetch `/api/v1/status` (public, no token). On failure, keep the previous status
  /// and record the error rather than blanking discovery.
  public func refresh() async {
    guard let url = serverConfig.baseURL else { return }
    do {
      status = try await makeSystemAPI(url).status()
      lastError = nil
    } catch let error as APIClientError {
      lastError = error
    } catch {
      lastError = .transport(error.localizedDescription)
    }
  }
}
