@testable import OpenCovenFeedback
import XCTest

final class JSBridgeTests: XCTestCase {
    // MARK: - Inbound commands (host -> widget)

    func testIdentifySSO() {
        let js = JSBridge.identifyCommand(ssoToken: "tok123")
        XCTAssertTrue(js.contains("window.postMessage"))
        XCTAssertTrue(js.contains("quackback:identify"))
        XCTAssertTrue(js.contains("\"ssoToken\":\"tok123\""))
    }

    func testIdentifyAttrs() {
        let js = JSBridge.identifyCommand(userId: "u1", email: "a@b.c", name: "A", avatarURL: nil)
        XCTAssertTrue(js.contains("quackback:identify"))
        XCTAssertTrue(js.contains("\"id\":\"u1\""))
        XCTAssertTrue(js.contains("\"email\":\"a@b.c\""))
    }

    func testIdentifyAttrsWithAvatarURL() {
        let js = JSBridge.identifyCommand(userId: "u1", email: "a@b.c", name: "A", avatarURL: "https://img.com/a.png")
        XCTAssertTrue(js.contains("\"avatarURL\""))
        XCTAssertTrue(js.contains("img.com"))
    }

    func testIdentifyAttrsWithoutName() {
        let js = JSBridge.identifyCommand(userId: "u1", email: "a@b.c", name: nil, avatarURL: nil)
        XCTAssertTrue(js.contains("\"id\":\"u1\""))
        XCTAssertFalse(js.contains("\"name\""))
        XCTAssertFalse(js.contains("\"avatarURL\""))
    }

    func testIdentifyAnonymousCommand() {
        let js = JSBridge.identifyAnonymousCommand()
        XCTAssertTrue(js.contains("quackback:identify"))
        XCTAssertTrue(js.contains("\"anonymous\":true"))
    }

    func testLogout() {
        XCTAssertEqual(JSBridge.logoutCommand(), "window.postMessage({type:'quackback:identify',data:null},'*');")
    }

    func testLocaleCommand() {
        let js = JSBridge.localeCommand("fr")
        XCTAssertTrue(js.contains("quackback:locale"))
        XCTAssertTrue(js.contains("'fr'") || js.contains("\"fr\""))
    }

    func testOpenBoard() {
        let js = JSBridge.openCommand(board: "bugs")
        XCTAssertTrue(js.contains("quackback:open"))
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
        XCTAssertEqual(JSBridge.openCommand(), "window.postMessage({type:'quackback:open'},'*');")
    }

    func testMetadataCommand() {
        let js = JSBridge.metadataCommand(["page": "/settings", "version": "2.4.1"])
        XCTAssertTrue(js.contains("quackback:metadata"))
        XCTAssertTrue(js.contains("\"page\":\"\\/settings\"") || js.contains("\"page\":\"/settings\""))
        XCTAssertTrue(js.contains("\"version\":\"2.4.1\""))
    }

    func testMetadataRemoveKey() {
        let js = JSBridge.metadataCommand(["stale": nil])
        XCTAssertTrue(js.contains("quackback:metadata"))
        XCTAssertTrue(js.contains("\"stale\":null"))
    }

    func testCommandsEndWithSemicolon() {
        XCTAssertTrue(JSBridge.identifyCommand(ssoToken: "t").hasSuffix(";"))
        XCTAssertTrue(JSBridge.identifyCommand(userId: "u", email: "e", name: nil, avatarURL: nil).hasSuffix(";"))
        XCTAssertTrue(JSBridge.identifyAnonymousCommand().hasSuffix(";"))
        XCTAssertTrue(JSBridge.localeCommand("fr").hasSuffix(";"))
        XCTAssertTrue(JSBridge.openCommand(board: "b").hasSuffix(";"))
        XCTAssertTrue(JSBridge.openCommand().hasSuffix(";"))
        XCTAssertTrue(JSBridge.logoutCommand().hasSuffix(";"))
        XCTAssertTrue(JSBridge.metadataCommand(["k": "v"]).hasSuffix(";"))
    }

    func testCommandsUseQuackbackNamespace() {
        XCTAssertFalse(JSBridge.identifyAnonymousCommand().contains("opencoven-feedback"))
        XCTAssertFalse(JSBridge.openCommand().contains("opencoven-feedback"))
        XCTAssertFalse(JSBridge.metadataCommand(["k": "v"]).contains("opencoven-feedback"))
    }

    // MARK: - Outbound parsing (widget -> host)
    // Mirrors the real dispatch format: dispatch(eventType, fullMessage), packed
    // by the bridge script as {event: eventType, data: fullMessage}.

    func testParseVoteEventWrapper() {
        let json = #"{"event":"event","data":{"type":"quackback:event","name":"vote","payload":{"postId":"post_abc","voted":true,"voteCount":3}}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .vote)
        XCTAssertEqual(p.data["postId"] as? String, "post_abc")
    }

    func testParsePostCreatedEventWrapper() {
        let json = #"{"event":"event","data":{"type":"quackback:event","name":"post:created","payload":{"id":"post_xyz","title":"Crash"}}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .postCreated)
        XCTAssertEqual(p.data["id"] as? String, "post_xyz")
    }

    func testParseCommentCreatedEventWrapper() {
        let json = #"{"event":"event","data":{"type":"quackback:event","name":"comment:created","payload":{"postId":"p1","commentId":"c1","parentId":null}}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .commentCreated)
        XCTAssertEqual(p.data["commentId"] as? String, "c1")
    }

    func testParseIdentifyEventWrapper() {
        let json = #"{"event":"event","data":{"type":"quackback:event","name":"identify","payload":{"success":true,"anonymous":false}}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .identify)
        XCTAssertEqual(p.data["success"] as? Bool, true)
    }

    func testParseOpenEventWrapper() {
        let json = #"{"event":"event","data":{"type":"quackback:event","name":"open","payload":{}}}"#
        XCTAssertEqual(JSBridge.parseEvent(json)?.event, .open)
    }

    func testParseReadyMessage() {
        XCTAssertEqual(JSBridge.parseEvent(#"{"event":"ready","data":{"type":"quackback:ready"}}"#)?.event, .ready)
    }

    func testParseCloseMessage() {
        XCTAssertEqual(JSBridge.parseEvent(#"{"event":"close","data":{"type":"quackback:close"}}"#)?.event, .close)
    }

    func testParseNavigateMessage() {
        let json = #"{"event":"navigate","data":{"type":"quackback:navigate","url":"/boards/bugs"}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .navigate)
        XCTAssertEqual(p.data["url"] as? String, "/boards/bugs")
    }

    func testParseIdentifyResultMessage() {
        let json = #"{"event":"identify-result","data":{"type":"quackback:identify-result","success":false,"error":"TOKEN_INVALID"}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertEqual(p.event, .identifyResult)
        XCTAssertEqual(p.data["error"] as? String, "TOKEN_INVALID")
    }

    func testParseAuthChangeMessage() {
        let json = #"{"event":"auth-change","data":{"type":"quackback:auth-change","user":null}}"#
        XCTAssertEqual(JSBridge.parseEvent(json)?.event, .authChange)
    }

    func testParseStripsTypeFromStandaloneData() {
        let json = #"{"event":"navigate","data":{"type":"quackback:navigate","url":"/x"}}"#
        let p = JSBridge.parseEvent(json)!
        XCTAssertNil(p.data["type"])
    }

    func testParseInvalid() {
        XCTAssertNil(JSBridge.parseEvent("bad"))
        XCTAssertNil(JSBridge.parseEvent(""))
        XCTAssertNil(JSBridge.parseEvent("{}"))
    }

    func testParseUnknownEventName() {
        let json = #"{"event":"event","data":{"type":"quackback:event","name":"nope","payload":{}}}"#
        XCTAssertNil(JSBridge.parseEvent(json))
    }

    func testParseUnknownMessageType() {
        XCTAssertNil(JSBridge.parseEvent(#"{"event":"made-up","data":{}}"#))
    }

    // MARK: - Bridge script

    func testBridgeScriptUsesValidQuackbackGlobal() {
        let script = JSBridge.bridgeScript
        XCTAssertTrue(script.contains("__quackbackNative"))
        XCTAssertTrue(script.contains("messageHandlers"))
        XCTAssertFalse(script.contains("opencoven-feedback"), "bridge must use the frozen quackback wire protocol")
    }
}
