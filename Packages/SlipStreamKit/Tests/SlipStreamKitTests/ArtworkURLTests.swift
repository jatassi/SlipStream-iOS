import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct ArtworkURLTests {
  let base = URL(string: "http://localhost:8080")!
  @Test func resolvesRelativePathAgainstBase() {
    #expect(
      resolveArtworkURL("/api/v1/metadata/artwork/movie/1/poster", base: base)?.absoluteString
        == "http://localhost:8080/api/v1/metadata/artwork/movie/1/poster")
  }
  @Test func passesThroughAbsoluteURL() {
    #expect(
      resolveArtworkURL("https://img.example/p.jpg", base: base)?.absoluteString
        == "https://img.example/p.jpg")
  }
  @Test func nilBaseWithRelativePathReturnsNil() {
    // scheme-less → nil, not a doomed URL
    #expect(resolveArtworkURL("/api/v1/x", base: nil) == nil)
  }
  @Test func nilAndEmptyInputReturnNil() {
    #expect(resolveArtworkURL(nil, base: base) == nil)
    #expect(resolveArtworkURL("", base: base) == nil)
  }
}
