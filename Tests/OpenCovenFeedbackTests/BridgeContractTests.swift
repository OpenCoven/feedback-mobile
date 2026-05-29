import JavaScriptCore
@testable import OpenCovenFeedback
import XCTest

/// Executes the injected bridge script in a real JS engine to prove it is valid
/// JavaScript and that `window.__quackbackNative.dispatch` routes messages to the
/// host the same way the web widget (`lib/client/widget-bridge.ts`) calls it.
///
/// String-`contains` assertions cannot catch an invalid-JS or wrong-global bridge;
/// these tests can.
final class BridgeContractTests: XCTestCase {
    /// Builds a JS context that mirrors the WKWebView environment: a `window`
    /// with `webkit.messageHandlers.quackback.postMessage` wired back to Swift,
    /// then evaluates the bridge script. Returns the context and a capture probe.
    private func makeContext(file: StaticString = #filePath, line: UInt = #line) -> (JSContext, () -> String?) {
        let context = JSContext()!
        var captured: String?
        let capture: @convention(block) (String) -> Void = { captured = $0 }
        context.setObject(capture, forKeyedSubscript: "__capture" as NSString)
        context.evaluateScript("""
        var window = this;
        window.webkit = { messageHandlers: { quackback: { postMessage: function (m) { __capture(m); } } } };
        """)
        context.evaluateScript(JSBridge.bridgeScript)
        XCTAssertNil(context.exception, "bridge script raised: \(String(describing: context.exception))", file: file, line: line)
        return (context, { captured })
    }

    func testBridgeScriptDefinesCallableDispatch() {
        let (context, _) = makeContext()
        let kind = context.evaluateScript("typeof window.__quackbackNative.dispatch")
        XCTAssertEqual(kind?.toString(), "function")
    }

    func testWidgetCanDetectNativeBridge() {
        // Mirrors the web `sendToHost` guard: `window.__quackbackNative?.dispatch`.
        let (context, _) = makeContext()
        let hasBridge = context.evaluateScript("!!(window.__quackbackNative && window.__quackbackNative.dispatch)")
        XCTAssertTrue(hasBridge?.toBool() ?? false)
    }

    func testDispatchEventWrapperReachesHostAndParses() {
        let (context, captured) = makeContext()
        context.evaluateScript("""
        window.__quackbackNative.dispatch('event', {
          type: 'quackback:event',
          name: 'vote',
          payload: { postId: 'p1', voted: true, voteCount: 5 }
        });
        """)
        XCTAssertNil(context.exception)
        guard let message = captured() else { return XCTFail("host received no message") }
        let parsed = JSBridge.parseEvent(message)
        XCTAssertEqual(parsed?.event, .vote)
        XCTAssertEqual(parsed?.data["postId"] as? String, "p1")
        XCTAssertEqual(parsed?.data["voteCount"] as? Int, 5)
    }

    func testDispatchReadyMessageParses() {
        let (context, captured) = makeContext()
        context.evaluateScript("window.__quackbackNative.dispatch('ready', { type: 'quackback:ready' });")
        XCTAssertEqual(JSBridge.parseEvent(captured()!)?.event, .ready)
    }

    func testDispatchCloseMessageParses() {
        let (context, captured) = makeContext()
        context.evaluateScript("window.__quackbackNative.dispatch('close', { type: 'quackback:close' });")
        XCTAssertEqual(JSBridge.parseEvent(captured()!)?.event, .close)
    }

    func testDispatchNavigateMessageParses() {
        let (context, captured) = makeContext()
        context.evaluateScript("window.__quackbackNative.dispatch('navigate', { type: 'quackback:navigate', url: '/boards/bugs' });")
        let parsed = JSBridge.parseEvent(captured()!)
        XCTAssertEqual(parsed?.event, .navigate)
        XCTAssertEqual(parsed?.data["url"] as? String, "/boards/bugs")
    }

    func testDispatchIdentifyResultMessageParses() {
        let (context, captured) = makeContext()
        context.evaluateScript("""
        window.__quackbackNative.dispatch('identify-result', {
          type: 'quackback:identify-result',
          success: true,
          user: { id: 'u1', name: 'Val', email: 'val@example.com', avatarUrl: null }
        });
        """)
        let parsed = JSBridge.parseEvent(captured()!)
        XCTAssertEqual(parsed?.event, .identifyResult)
        XCTAssertEqual(parsed?.data["success"] as? Bool, true)
    }
}
