import Foundation

/// URLSession-backed client for the portal surface under `/api/v1/requests`.
public final class PortalAPIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    private struct ServerErrorBody: Decodable {
        let message: String?
        let error: String?
    }

    /// `path` is relative to `basePath`, no leading slash, e.g. "auth/login".
    /// `basePath` defaults to the portal base; `/status` lives one level up at "api/v1".
    func send<T: Decodable>(
        path: String,
        method: String,
        token: String?,
        body: Data?,
        basePath: String = "api/v1/requests"
    ) async throws -> T {
        let url = baseURL
            .appendingPathComponent(basePath)
            .appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
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
            let payload = try? JSONDecoder().decode(ServerErrorBody.self, from: data)
            throw APIClientError.http(
                status: http.statusCode,
                message: payload?.message,
                error: payload?.error
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIClientError.decoding(String(describing: error))
        }
    }
}

extension PortalAPIClient: AuthAPI {
    public func login(_ body: LoginRequest) async throws -> LoginResponse {
        let encoded = try JSONEncoder().encode(body)
        return try await send(path: "auth/login", method: "POST", token: nil, body: encoded)
    }

    public func profile(token: String) async throws -> PortalUser {
        try await send(path: "auth/profile", method: "GET", token: token, body: nil)
    }
}

extension PortalAPIClient: SystemAPI {
    public func status() async throws -> SystemStatus {
        try await send(path: "status", method: "GET", token: nil, body: nil, basePath: "api/v1")
    }
}
