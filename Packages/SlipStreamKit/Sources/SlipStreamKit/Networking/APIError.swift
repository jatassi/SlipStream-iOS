import Foundation

/// Typed failures from PortalAPIClient. Mirrors the web client's ApiError(status, {message?, error?}).
public enum APIClientError: Error, Equatable, Sendable {
  case http(status: Int, message: String?, error: String?)
  case decoding(String)
  case transport(String)
}
