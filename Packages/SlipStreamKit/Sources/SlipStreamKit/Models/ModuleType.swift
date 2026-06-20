/// The media modules the portal can expose. Raw values mirror the server's module
/// type strings (`internal/module/types.go`: `TypeMovie = "movie"`, `TypeTV = "tv"`).
public enum ModuleType: String, Codable, CaseIterable, Sendable {
  case movie
  case tv
}
