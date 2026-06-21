import Foundation
import Observation

/// Drives invitation signup (F2.5): parse a pasted link, validate the token, choose a PIN,
/// and commit the session. Mirrors the web `signup.tsx` four-state route. UI binds to `phase`.
@MainActor
@Observable
public final class InvitationSignupStore {
  public enum InvalidReason: Equatable, Sendable {
    case notFound, expired, used, badToken
    case network(String)
  }

  public enum Phase: Equatable, Sendable {
    case awaitingToken
    case validating
    case invalid(InvalidReason)
    case ready(username: String)
    case creatingAccount
  }

  public private(set) var phase: Phase = .awaitingToken
  /// Inline error on the paste screen (unparseable input); distinct from `.invalid`,
  /// which means the server rejected an otherwise well-formed token.
  public private(set) var pasteError: String?
  /// Transient error shown on the create-PIN screen after a recoverable signup failure
  /// (e.g. network) — the phase returns to `.ready` so the user can retry.
  public private(set) var submitError: String?

  private let makeAuthAPI: @Sendable (URL) -> AuthAPI
  private let serverConfig: ServerConfigStore
  private let auth: AuthStore

  private var serverURL: URL?
  private var token: String?
  private var validatedUsername: String?

  /// Bumped whenever a new user-initiated operation starts (`submitInviteLink`, `retryValidation`,
  /// `createAccount`) or the flow is `reset()`. Each async operation captures the value at its start
  /// and, after every `await`, ignores its own result if the value has since changed — so a Task that
  /// resumes after the sheet was cancelled/reopened (or superseded by a rapid re-tap) can't clobber
  /// the current state with a stale phase. (`@MainActor` makes the read/bump race-free.)
  private var generation = 0

  public init(
    makeAuthAPI: @escaping @Sendable (URL) -> AuthAPI,
    serverConfig: ServerConfigStore,
    auth: AuthStore
  ) {
    self.makeAuthAPI = makeAuthAPI
    self.serverConfig = serverConfig
    self.auth = auth
  }

  /// Parse a pasted invitation (full link → origin + token, or a bare token when a server is
  /// already configured), then validate it. Unparseable input keeps the paste screen up.
  public func submitInviteLink(_ pasted: String) async {
    let expectedGeneration = beginOperation()
    pasteError = nil
    submitError = nil
    guard let parsed = InviteLinkParser.parse(pasted, configuredServer: serverConfig.baseURL)
    else {
      phase = .awaitingToken
      pasteError = "That doesn't look like a valid invitation link."
      return
    }
    serverURL = parsed.serverURL
    token = parsed.token
    await runValidation(expectedGeneration)
  }

  /// Re-run validation against the already-parsed token (the Retry affordance on a network failure).
  public func retryValidation() async {
    await runValidation(beginOperation())
  }

  private func runValidation(_ expectedGeneration: Int) async {
    guard let serverURL, let token else { return }
    phase = .validating
    let result = await validate(serverURL: serverURL, token: token)
    // Discard a result that a later `reset()`/operation has superseded (see `generation`).
    guard expectedGeneration == generation else { return }
    if case .ready(let username) = result {
      validatedUsername = username
    }
    phase = result
  }

  /// Pure mapping from the validate-invitation call to its resulting phase — no state mutation,
  /// so a superseded caller can drop the result. `valid:false` or an unexpected status → `.badToken`;
  /// 404/410/409 → the matching reason; transport/decoding → a retryable `.network`.
  private func validate(serverURL: URL, token: String) async -> Phase {
    do {
      let resp = try await makeAuthAPI(serverURL).validateInvitation(token: token)
      return resp.valid ? .ready(username: resp.username) : .invalid(.badToken)
    } catch let APIClientError.http(status, _, _) {
      return .invalid(Self.invalidReason(forStatus: status))
    } catch let APIClientError.transport(message) {
      return .invalid(.network(message))
    } catch let APIClientError.decoding(message) {
      return .invalid(.network(message))
    } catch {
      return .invalid(.network(String(describing: error)))
    }
  }

  /// Redeem the invitation with the chosen 4-digit PIN and, on success, commit the returned
  /// session through `AuthStore` (auto-sign-in). A consumed/expired/missing invite becomes
  /// `.invalid`; a recoverable failure returns to `.ready` with `submitError`.
  public func createAccount(pin: String) async {
    let expectedGeneration = beginOperation()
    submitError = nil
    guard let serverURL, let token, let username = validatedUsername else { return }
    phase = .creatingAccount
    do {
      let resp = try await makeAuthAPI(serverURL).signup(SignupRequest(token: token, password: pin))
      // The session commit always runs once the signup POST succeeds — the account now exists and
      // the token is consumed, so completing sign-in is correct even if the sheet was dismissed.
      try auth.establishSession(
        serverURL: serverURL, token: resp.token, user: resp.user, username: resp.user.username)
      // Session committed; AuthGateView swaps the signed-out tree (and this sheet) away.
    } catch let APIClientError.http(status, _, _)
      where status == 409 || status == 410 || status == 404
    {
      guard expectedGeneration == generation else { return }
      phase = .invalid(Self.invalidReason(forStatus: status))
    } catch APIClientError.http {
      guard expectedGeneration == generation else { return }
      submitError = "Couldn't create your account. Please try again."
      phase = .ready(username: username)
    } catch APIClientError.transport {
      guard expectedGeneration == generation else { return }
      submitError = "Network error. Please try again."
      phase = .ready(username: username)
    } catch {
      guard expectedGeneration == generation else { return }
      submitError = "Couldn't create your account. Please try again."
      phase = .ready(username: username)
    }
  }

  /// Return to the paste screen and forget any in-flight invitation (used when the signup
  /// sheet is reopened or the user chooses to try another link). Bumps `generation` so any
  /// Task still awaiting a network response abandons its result instead of clobbering this state.
  public func reset() {
    generation += 1
    phase = .awaitingToken
    pasteError = nil
    submitError = nil
    serverURL = nil
    token = nil
    validatedUsername = nil
  }

  /// Start a new user-initiated operation: bump `generation` and return the new value for the
  /// caller to capture and re-check after its awaits.
  private func beginOperation() -> Int {
    generation += 1
    return generation
  }

  private static func invalidReason(forStatus status: Int) -> InvalidReason {
    switch status {
    case 404: return .notFound
    case 410: return .expired
    case 409: return .used
    default: return .badToken
    }
  }
}
