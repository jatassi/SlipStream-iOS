import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct JSONValueTests {
  @Test func decodesEveryScalarAndNestedShape() throws {
    let json = """
      {
        "webhookUrl": "https://hooks.example.com/abc",
        "port": 8080,
        "secure": true,
        "retries": null,
        "channels": ["general", "alerts"],
        "headers": { "X-Token": "t", "count": 3 }
      }
      """
    let decoded = try JSONDecoder().decode([String: JSONValue].self, from: Data(json.utf8))
    #expect(decoded["webhookUrl"] == .string("https://hooks.example.com/abc"))
    #expect(decoded["port"] == .number(8080))
    #expect(decoded["secure"] == .bool(true))
    #expect(decoded["retries"] == .null)
    #expect(decoded["channels"] == .array([.string("general"), .string("alerts")]))
    #expect(decoded["headers"] == .object(["X-Token": .string("t"), "count": .number(3)]))
  }

  @Test func roundTripsThroughEncodeAndDecode() throws {
    let original: JSONValue = .object([
      "a": .array([.number(1), .bool(false), .null]),
      "b": .string("x"),
    ])
    let data = try JSONEncoder().encode(original)
    let restored = try JSONDecoder().decode(JSONValue.self, from: data)
    #expect(restored == original)
  }

  @Test func encodesNullAsJSONNull() throws {
    let data = try JSONEncoder().encode(JSONValue.null)
    #expect(String(data: data, encoding: .utf8) == "null")
  }
}
