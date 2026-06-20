import Foundation

/// `URLSession`-backed client for the SlipStream HTTP API.
///
/// Most calls target the portal surface under `/api/v1/requests`; the same client can also
/// reach the shared `/api/v1/metadata` group and the public `/api/v1/status` endpoint by
/// passing a different `APIBase`. Decode JSON responses with `send`; use `sendNoContent`
/// for endpoints that return `204 No Content`.
public final class PortalAPIClient: Sendable {
  private let baseURL: URL
  private let session: URLSession
  private let onUnauthorized: (@Sendable () -> Void)?

  public init(
    baseURL: URL,
    session: URLSession = .shared,
    onUnauthorized: (@Sendable () -> Void)? = nil
  ) {
    self.baseURL = baseURL
    self.session = session
    self.onUnauthorized = onUnauthorized
  }

  private struct ServerErrorBody: Decodable {
    let message: String?
    let error: String?
  }

  /// Performs the request and returns the raw response body (empty `Data` for `204`).
  /// Maps transport failures, non-HTTP responses, and non-2xx statuses to `APIClientError`.
  private func perform(
    _ path: String,
    method: HTTPMethod,
    base: APIBase,
    token: String?,
    body: Data?
  ) async throws -> Data {
    let url =
      baseURL
      .appendingPathComponent(base.pathPrefix)
      .appendingPathComponent(path)
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    request.httpBody = body

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw APIClientError.transport(error.localizedDescription)
    }

    guard let http = response as? HTTPURLResponse else {
      throw APIClientError.transport("Non-HTTP response")
    }
    guard (200..<300).contains(http.statusCode) else {
      // Mirror the web client: signal unauthorized only when the request carried a
      // token, so a bad-PIN login 401 (no token) stays local to sign-in.
      if http.statusCode == 401, token != nil {
        onUnauthorized?()
      }
      let payload = try? JSONDecoder().decode(ServerErrorBody.self, from: data)
      throw APIClientError.http(
        status: http.statusCode,
        message: payload?.message,
        error: payload?.error
      )
    }
    return data
  }

  /// Sends a request and decodes a JSON body into `T`.
  /// Use `sendNoContent` for endpoints that return `204 No Content`.
  /// - Parameters:
  ///   - path: path relative to `base`, no leading slash (e.g. `"auth/login"`, `"movie/603"`, `"status"`).
  ///   - method: HTTP verb; defaults to `.get`.
  ///   - base: which API root to target; defaults to `.portal`.
  ///   - token: optional bearer token.
  ///   - body: optional pre-encoded request body.
  public func send<T: Decodable>(
    _ path: String,
    method: HTTPMethod = .get,
    base: APIBase = .portal,
    token: String? = nil,
    body: Data? = nil
  ) async throws -> T {
    let data = try await perform(path, method: method, base: base, token: token, body: body)
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw APIClientError.decoding(String(describing: error))
    }
  }

  /// Sends a request that returns no body (`204 No Content` / empty), e.g. cancel,
  /// unwatch, inbox mark-read, or a saved-channel test. Throws on any non-2xx status.
  public func sendNoContent(
    _ path: String,
    method: HTTPMethod = .get,
    base: APIBase = .portal,
    token: String? = nil,
    body: Data? = nil
  ) async throws {
    _ = try await perform(path, method: method, base: base, token: token, body: body)
  }
}

extension PortalAPIClient: AuthAPI {
  public func login(_ body: LoginRequest) async throws -> LoginResponse {
    let encoded = try JSONEncoder().encode(body)
    return try await send("auth/login", method: .post, base: .portal, token: nil, body: encoded)
  }

  public func profile(token: String) async throws -> PortalUser {
    try await send("auth/profile", method: .get, base: .portal, token: token)
  }
}

extension PortalAPIClient: SystemAPI {
  public func status() async throws -> SystemStatus {
    try await send("status", base: .status)
  }
}
