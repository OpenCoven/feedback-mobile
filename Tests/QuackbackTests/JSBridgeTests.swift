import XCTest
@testable import Quackback

final class JSBridgeTests: XCTestCase {
    func testInitCommand() {
        let config = QuackbackConfig(appId: "app1", baseURL: URL(string: "https://x.com")!, theme: .dark, locale: "fr")
        let js = JSBridge.initCommand(config: config)
        XCTAssertTrue(js.contains("Quackback('init'")); XCTAssertTrue(js.contains("\"appId\":\"app1\""))
        XCTAssertTrue(js.contains("\"theme\":\"dark\"")); XCTAssertTrue(js.contains("\"locale\":\"fr\""))
    }
    func testIdentifySSO() {
        XCTAssertTrue(JSBridge.identifyCommand(ssoToken: "tok123").contains("\"ssoToken\":\"tok123\""))
    }
    func testIdentifyAttrs() {
        let js = JSBridge.identifyCommand(userId: "u1", email: "a@b.c", name: "A", avatarURL: nil)
        XCTAssertTrue(js.contains("\"id\":\"u1\"")); XCTAssertTrue(js.contains("\"email\":\"a@b.c\""))
    }
    func testOpenBoard() { XCTAssertTrue(JSBridge.openCommand(board: "bugs").contains("\"board\":\"bugs\"")) }
    func testOpenNil() { XCTAssertEqual(JSBridge.openCommand(board: nil), "Quackback('open');") }
    func testLogout() { XCTAssertEqual(JSBridge.logoutCommand(), "Quackback('logout');") }
    func testParseVoteEvent() {
        let json = #"{"event":"vote","data":{"type":"quackback:event","name":"vote","payload":{"postId":"post_abc"}}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .vote); XCTAssertEqual(p.data["postId"] as? String, "post_abc")
    }
    func testParseReady() {
        XCTAssertEqual(JSBridge.parseEvent(#"{"event":"ready","data":{"type":"quackback:ready"}}"#)!.event, .ready)
    }
    func testParseInvalid() { XCTAssertNil(JSBridge.parseEvent("bad")) }
}
