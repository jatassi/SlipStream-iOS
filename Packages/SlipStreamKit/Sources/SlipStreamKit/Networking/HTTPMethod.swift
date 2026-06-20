/// HTTP verbs used by `PortalAPIClient`. Raw values are the wire method names.
public enum HTTPMethod: String, Sendable {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case delete = "DELETE"
  case patch = "PATCH"
}
