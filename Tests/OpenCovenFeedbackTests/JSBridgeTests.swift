@testable import OpenCovenFeedback
import XCTest

final class JSBridgeTests: XCTestCase {
    func testInitCommand() {
        let config = OpenCovenFeedbackConfig(instanceUrl: URL(string: "https://x.com")!, theme: .dark, locale: "fr")
        let js = JSBridge.initCommand(config: config)
        XCTAssertTrue(js.contains("window.postMessage"))
        XCTAssertTrue(js.contains("opencoven-feedback:init"))
        XCTAssertTrue(js.contains("\"theme\":\"dark\""))
        XCTAssertTrue(js.contains("\"locale\":\"fr\""))
        XCTAssertFalse(js.contains("appId"))
    }
    func testIdentifySSO() {
        let js = JSBridge.identifyCommand(ssoToken: "tok123")
        XCTAssertTrue(js.contains("window.postMessage")); XCTAssertTrue(js.contains("opencoven-feedback:identify"))
        XCTAssertTrue(js.contains("\"ssoToken\":\"tok123\""))
    }
    func testIdentifyAttrs() {
        let js = JSBridge.identifyCommand(userId: "u1", email: "a@b.c", name: "A", avatarURL: nil)
        XCTAssertTrue(js.contains("window.postMessage")); XCTAssertTrue(js.contains("opencoven-feedback:identify"))
        XCTAssertTrue(js.contains("\"id\":\"u1\"")); XCTAssertTrue(js.contains("\"email\":\"a@b.c\""))
    }
    func testIdentifyAnonymousCommand() {
        let js = JSBridge.identifyAnonymousCommand()
        XCTAssertTrue(js.contains("window.postMessage")); XCTAssertTrue(js.contains("opencoven-feedback:identify"))
        XCTAssertTrue(js.contains("\"anonymous\":true"))
    }
    func testOpenBoard() {
        let js = JSBridge.openCommand(board: "bugs")
        XCTAssertTrue(js.contains("window.postMessage")); XCTAssertTrue(js.contains("opencoven-feedback:open"))
        XCTAssertTrue(js.contains("\"board\":\"bugs\""))
    }
    func testOpenView() {
        let js = JSBridge.openCommand(view: .newPost, title: "Bug:")
        XCTAssertTrue(js.contains("\"view\":\"new-post\""))
        XCTAssertTrue(js.contains("\"title\":\"Bug:\""))
    }
    func testOpenViewAndBoard() {
        let js = JSBridge.openCommand(view: .newPost, title: "Crash", board: "bugs")
        XCTAssertTrue(js.contains("\"view\":\"new-post\""))
        XCTAssertTrue(js.contains("\"board\":\"bugs\""))
        XCTAssertTrue(js.contains("\"title\":\"Crash\""))
    }
    func testOpenEmpty() {
        XCTAssertEqual(JSBridge.openCommand(), "window.postMessage({type:'opencoven-feedback:open'},'*');")
    }
    func testLogout() { XCTAssertEqual(JSBridge.logoutCommand(), "window.postMessage({type:'opencoven-feedback:identify',data:null},'*');") }
    func testMetadataCommand() {
        let js = JSBridge.metadataCommand(["page": "/settings", "version": "2.4.1"])
        XCTAssertTrue(js.contains("opencoven-feedback:metadata"))
        XCTAssertTrue(js.contains("\"page\":\"\\/settings\"") || js.contains("\"page\":\"/settings\""))
        XCTAssertTrue(js.contains("\"version\":\"2.4.1\""))
    }
    func testMetadataRemoveKey() {
        let js = JSBridge.metadataCommand(["stale": nil])
        XCTAssertTrue(js.contains("opencoven-feedback:metadata"))
        XCTAssertTrue(js.contains("\"stale\":null"))
    }
    func testParseVoteEvent() {
        let json = #"{"event":"vote","data":{"type":"opencoven-feedback:event","name":"vote","payload":{"postId":"post_abc"}}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .vote); XCTAssertEqual(p.data["postId"] as? String, "post_abc")
    }
    func testParseReady() {
        XCTAssertEqual(JSBridge.parseEvent(#"{"event":"ready","data":{"type":"opencoven-feedback:ready"}}"#)!.event, .ready)
    }
    func testParseInvalid() { XCTAssertNil(JSBridge.parseEvent("bad")) }

    func testInitCommandWithoutLocale() {
        let config = OpenCovenFeedbackConfig(instanceUrl: URL(string: "https://x.com")!, theme: .light)
        let js = JSBridge.initCommand(config: config)
        XCTAssertTrue(js.contains("\"theme\":\"light\""))
        XCTAssertFalse(js.contains("locale"))
    }

    func testInitCommandSystemTheme() {
        let config = OpenCovenFeedbackConfig(instanceUrl: URL(string: "https://x.com")!)
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
        let json = #"{"event":"close","data":{"type":"opencoven-feedback:close"}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .close)
    }

    func testParseSubmitEvent() {
        let json = #"{"event":"submit","data":{"type":"opencoven-feedback:event","name":"submit","payload":{"postId":"post_xyz"}}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .submit)
        XCTAssertEqual(p.data["postId"] as? String, "post_xyz")
    }

    func testParseNavigateEvent() {
        let json = #"{"event":"navigate","data":{"type":"opencoven-feedback:navigate","payload":{"path":"/boards/bugs"}}}"#
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
        XCTAssertTrue(JSBridge.bridgeScript.contains("__opencoven-feedbackNative"))
        XCTAssertTrue(JSBridge.bridgeScript.contains("messageHandlers"))
        XCTAssertTrue(JSBridge.bridgeScript.contains("opencoven-feedback"))
    }

    func testCommandsEndWithSemicolon() {
        let config = OpenCovenFeedbackConfig(instanceUrl: URL(string: "https://x.com")!)
        XCTAssertTrue(JSBridge.initCommand(config: config).hasSuffix(";"))
        XCTAssertTrue(JSBridge.identifyCommand(ssoToken: "t").hasSuffix(";"))
        XCTAssertTrue(JSBridge.identifyCommand(userId: "u", email: "e", name: nil, avatarURL: nil).hasSuffix(";"))
        XCTAssertTrue(JSBridge.identifyAnonymousCommand().hasSuffix(";"))
        XCTAssertTrue(JSBridge.openCommand(board: "b").hasSuffix(";"))
        XCTAssertTrue(JSBridge.openCommand().hasSuffix(";"))
        XCTAssertTrue(JSBridge.logoutCommand().hasSuffix(";"))
        XCTAssertTrue(JSBridge.metadataCommand(["k": "v"]).hasSuffix(";"))
    }

    func testCommandsStartWithPostMessage() {
        let config = OpenCovenFeedbackConfig(instanceUrl: URL(string: "https://x.com")!)
        XCTAssertTrue(JSBridge.initCommand(config: config).contains("window.postMessage"))
        XCTAssertTrue(JSBridge.identifyCommand(ssoToken: "t").contains("window.postMessage"))
        XCTAssertTrue(JSBridge.identifyAnonymousCommand().contains("window.postMessage"))
        XCTAssertTrue(JSBridge.openCommand().contains("window.postMessage"))
        XCTAssertTrue(JSBridge.logoutCommand().contains("window.postMessage"))
        XCTAssertTrue(JSBridge.metadataCommand(["k": "v"]).contains("window.postMessage"))
    }
}
