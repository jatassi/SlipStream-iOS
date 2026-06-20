import Foundation
import Testing

@testable import SlipStreamKit

@Suite struct EnumDecodingTests {
  @Test func requestStatusHasEightStatesInContractOrder() throws {
    let json =
      #"["pending","approved","denied","searching","downloading","failed","available","cancelled"]"#
    let decoded = try JSONDecoder().decode([RequestStatus].self, from: Data(json.utf8))
    #expect(decoded == RequestStatus.allCases)
    #expect(RequestStatus.allCases.count == 8)
    #expect(RequestStatus.downloading.rawValue == "downloading")
  }

  @Test func portalMediaTypeMirrorsContract() throws {
    let json = #"["movie","series","season","episode"]"#
    let decoded = try JSONDecoder().decode([PortalMediaType].self, from: Data(json.utf8))
    #expect(decoded == PortalMediaType.allCases)
  }

  @Test func portalDownloadStatusMirrorsContract() throws {
    let json = #"["queued","downloading","paused","completed","failed","warning"]"#
    let decoded = try JSONDecoder().decode([PortalDownloadStatus].self, from: Data(json.utf8))
    #expect(decoded == PortalDownloadStatus.allCases)
  }

  @Test func requestScopeMirrorsContract() throws {
    #expect(RequestScope(rawValue: "mine") == .mine)
    #expect(RequestScope(rawValue: "all") == .all)
    #expect(RequestScope(rawValue: "nope") == nil)
  }
}
