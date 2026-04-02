import XCTest
@testable import Quackback

final class JSBridgeTests: XCTestCase {
    func testInitCommand() {
        let config = QuackbackConfig(appId: "app1", baseURL: URL(string: "https://x.com")!, theme: .dark, locale: "fr")
        let js = JSBridge.initCommand(config: config)
        XCTAssertTrue(js.contains("window.postMessage")); XCTAssertTrue(js.contains("quackback:init"))
        XCTAssertTrue(js.contains("\"appId\":\"app1\""))
        XCTAssertTrue(js.contains("\"theme\":\"dark\"")); XCTAssertTrue(js.contains("\"locale\":\"fr\""))
    }
    func testIdentifySSO() {
        let js = JSBridge.identifyCommand(ssoToken: "tok123")
        XCTAssertTrue(js.contains("window.postMessage")); XCTAssertTrue(js.contains("quackback:identify"))
        XCTAssertTrue(js.contains("\"ssoToken\":\"tok123\""))
    }
    func testIdentifyAttrs() {
        let js = JSBridge.identifyCommand(userId: "u1", email: "a@b.c", name: "A", avatarURL: nil)
        XCTAssertTrue(js.contains("window.postMessage")); XCTAssertTrue(js.contains("quackback:identify"))
        XCTAssertTrue(js.contains("\"id\":\"u1\"")); XCTAssertTrue(js.contains("\"email\":\"a@b.c\""))
    }
    func testOpenBoard() {
        let js = JSBridge.openCommand(board: "bugs")
        XCTAssertTrue(js.contains("window.postMessage")); XCTAssertTrue(js.contains("quackback:open"))
        XCTAssertTrue(js.contains("\"board\":\"bugs\""))
    }
    func testOpenNil() { XCTAssertEqual(JSBridge.openCommand(board: nil), "window.postMessage({type:'quackback:open'},'*');") }
    func testLogout() { XCTAssertEqual(JSBridge.logoutCommand(), "window.postMessage({type:'quackback:identify',data:null},'*');") }
    func testParseVoteEvent() {
        let json = #"{"event":"vote","data":{"type":"quackback:event","name":"vote","payload":{"postId":"post_abc"}}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .vote); XCTAssertEqual(p.data["postId"] as? String, "post_abc")
    }
    func testParseReady() {
        XCTAssertEqual(JSBridge.parseEvent(#"{"event":"ready","data":{"type":"quackback:ready"}}"#)!.event, .ready)
    }
    func testParseInvalid() { XCTAssertNil(JSBridge.parseEvent("bad")) }

    func testInitCommandWithoutLocale() {
        let config = QuackbackConfig(appId: "app1", baseURL: URL(string: "https://x.com")!, theme: .light)
        let js = JSBridge.initCommand(config: config)
        XCTAssertTrue(js.contains("\"theme\":\"light\""))
        XCTAssertFalse(js.contains("locale"))
    }

    func testInitCommandSystemTheme() {
        let config = QuackbackConfig(appId: "app1", baseURL: URL(string: "https://x.com")!)
        let js = JSBridge.initCommand(config: config)
        XCTAssertTrue(js.contains("\"theme\":\"user\""))
    }

    func testIdentifyAttrsWithAvatarURL() {
        let js = JSBridge.identifyCommand(userId: "u1", email: "a@b.c", name: "A", avatarURL: "https://img.com/a.png")
        XCTAssertTrue(js.contains("\"avatarURL\""))
        XCTAssertTrue(js.contains("img.com"))
    }

    func testIdentifyAttrsWithoutName() {
        let js = JSBridge.identifyCommand(userId: "u1", email: "a@b.c", name: nil, avatarURL: nil)
        XCTAssertTrue(js.contains("\"id\":\"u1\""))
        XCTAssertTrue(js.contains("\"email\":\"a@b.c\""))
        XCTAssertFalse(js.contains("\"name\""))
        XCTAssertFalse(js.contains("\"avatarURL\""))
    }

    func testParseCloseEvent() {
        let json = #"{"event":"close","data":{"type":"quackback:close"}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .close)
    }

    func testParseSubmitEvent() {
        let json = #"{"event":"submit","data":{"type":"quackback:event","name":"submit","payload":{"postId":"post_xyz"}}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .submit)
        XCTAssertEqual(p.data["postId"] as? String, "post_xyz")
    }

    func testParseNavigateEvent() {
        let json = #"{"event":"navigate","data":{"type":"quackback:navigate","payload":{"path":"/boards/bugs"}}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .navigate)
        XCTAssertEqual(p.data["path"] as? String, "/boards/bugs")
    }

    func testParseEmptyJSON() {
        XCTAssertNil(JSBridge.parseEvent(""))
        XCTAssertNil(JSBridge.parseEvent("{}"))
    }

    func testParseUnknownEventType() {
        let json = #"{"event":"unknown_event","data":{}}"#
        XCTAssertNil(JSBridge.parseEvent(json))
    }

    func testBridgeScriptContainsDispatch() {
        XCTAssertTrue(JSBridge.bridgeScript.contains("__quackbackNative"))
        XCTAssertTrue(JSBridge.bridgeScript.contains("messageHandlers"))
        XCTAssertTrue(JSBridge.bridgeScript.contains("quackback"))
    }

    func testCommandsEndWithSemicolon() {
        let config = QuackbackConfig(appId: "x", baseURL: URL(string: "https://x.com")!)
        XCTAssertTrue(JSBridge.initCommand(config: config).hasSuffix(";"))
        XCTAssertTrue(JSBridge.identifyCommand(ssoToken: "t").hasSuffix(";"))
        XCTAssertTrue(JSBridge.identifyCommand(userId: "u", email: "e", name: nil, avatarURL: nil).hasSuffix(";"))
        XCTAssertTrue(JSBridge.openCommand(board: "b").hasSuffix(";"))
        XCTAssertTrue(JSBridge.openCommand(board: nil).hasSuffix(";"))
        XCTAssertTrue(JSBridge.logoutCommand().hasSuffix(";"))
    }

    func testCommandsStartWithPostMessage() {
        let config = QuackbackConfig(appId: "x", baseURL: URL(string: "https://x.com")!)
        XCTAssertTrue(JSBridge.initCommand(config: config).contains("window.postMessage"))
        XCTAssertTrue(JSBridge.identifyCommand(ssoToken: "t").contains("window.postMessage"))
        XCTAssertTrue(JSBridge.openCommand(board: nil).contains("window.postMessage"))
        XCTAssertTrue(JSBridge.logoutCommand().contains("window.postMessage"))
    }
}
