import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct ServerURLValidatorTests {
  private func url(_ urlString: String) -> URL { URL(string: urlString)! }

  @Test func httpsIsAlwaysAcceptable() {
    #expect(
      ServerURLValidator.isAcceptable(
        url("https://slipstream.atassi.org"), allowInsecureLocal: false))
    #expect(ServerURLValidator.isAcceptable(url("https://example.com"), allowInsecureLocal: true))
  }

  @Test func httpToLocalIsAcceptableOnlyWhenAllowed() {
    let localhost = url("http://localhost:8080")
    let dotLocal = url("http://my-mac.local:8080")
    let loopback = url("http://127.0.0.1:8080")
    for testURL in [localhost, dotLocal, loopback] {
      #expect(ServerURLValidator.isAcceptable(testURL, allowInsecureLocal: true))
      #expect(!ServerURLValidator.isAcceptable(testURL, allowInsecureLocal: false))
    }
  }

  @Test func httpToPublicHostIsNeverAcceptable() {
    #expect(
      !ServerURLValidator.isAcceptable(
        url("http://slipstream.atassi.org"), allowInsecureLocal: true))
    #expect(!ServerURLValidator.isAcceptable(url("http://example.com"), allowInsecureLocal: true))
  }

  @Test func missingSchemeOrHostIsRejected() {
    #expect(!ServerURLValidator.isAcceptable(url("ftp://localhost"), allowInsecureLocal: true))
    #expect(!ServerURLValidator.isAcceptable(url("https:///"), allowInsecureLocal: true))
  }

  @Test func isLocalHostRecognizesLocalForms() {
    #expect(ServerURLValidator.isLocalHost("localhost"))
    #expect(ServerURLValidator.isLocalHost("My-Mac.local"))
    #expect(ServerURLValidator.isLocalHost("127.0.0.1"))
    #expect(ServerURLValidator.isLocalHost("::1"))
    #expect(ServerURLValidator.isLocalHost("devbox"))  // bare, dot-less
    #expect(!ServerURLValidator.isLocalHost("example.com"))
    #expect(!ServerURLValidator.isLocalHost("slipstream.atassi.org"))
  }

  @Test func debugBuildAllowsInsecureLocal() {
    // Tests build in Debug; this guards the compile flag's Debug branch.
    #expect(DevSupport.allowsInsecureLocalServers)
  }
}
