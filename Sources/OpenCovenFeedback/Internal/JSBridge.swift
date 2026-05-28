import Foundation

/// Builds and parses the `quackback:` postMessage protocol shared by every
/// OpenCoven Feedback client. The wire namespace is frozen as `quackback:` for
/// backward compatibility — it is intentionally not rebranded.
///
/// Source of truth: `lib/shared/widget/types.ts` and `lib/client/widget-bridge.ts`
/// in the OpenCoven/feedback repo.
enum JSBridge {
    struct ParsedEvent { let event: OpenCovenFeedbackEvent; let data: [String: Any] }

    // MARK: - Inbound commands (host -> widget)

    static func localeCommand(_ locale: String) -> String {
        "window.postMessage({type:'quackback:locale',data:'\(locale)'},'*');"
    }

    static func identifyCommand(ssoToken: String) -> String {
        "window.postMessage({type:'quackback:identify',data:\(json(["ssoToken": ssoToken]))},'*');"
    }

    static func identifyCommand(userId: String, email: String, name: String?, avatarURL: String?) -> String {
        var p: [String: String] = ["id": userId, "email": email]
        if let n = name { p["name"] = n }
        if let a = avatarURL { p["avatarURL"] = a }
        return "window.postMessage({type:'quackback:identify',data:\(json(p))},'*');"
    }

    static func identifyAnonymousCommand() -> String {
        "window.postMessage({type:'quackback:identify',data:{\"anonymous\":true}},'*');"
    }

    static func logoutCommand() -> String { "window.postMessage({type:'quackback:identify',data:null},'*');" }

    static func openCommand(view: OpenView? = nil, title: String? = nil, board: String? = nil) -> String {
        var p: [String: String] = [:]
        if let v = view { p["view"] = v.rawValue }
        if let t = title { p["title"] = t }
        if let b = board { p["board"] = b }
        if p.isEmpty { return "window.postMessage({type:'quackback:open'},'*');" }
        return "window.postMessage({type:'quackback:open',data:\(json(p))},'*');"
    }

    static func metadataCommand(_ patch: [String: String?]) -> String {
        // nil values mean "remove this key" — the iframe interprets null as delete
        var dict: [String: Any] = [:]
        for (k, v) in patch { dict[k] = v as Any? ?? NSNull() }
        let d = try! JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        let json = String(data: d, encoding: .utf8)!
        return "window.postMessage({type:'quackback:metadata',data:\(json)},'*');"
    }

    // MARK: - Outbound parsing (widget -> host)

    /// The widget calls `window.__quackbackNative.dispatch(eventType, message)`.
    /// The bridge script packs that as `{event: eventType, data: message}`.
    ///
    /// For `eventType == "event"` the real event name and payload live inside the
    /// message (`quackback:event` wrapper). All other types are standalone
    /// outbound messages (`ready`, `close`, `navigate`, `identify-result`,
    /// `auth-change`) whose data is the message body minus its `type` key.
    static func parseEvent(_ jsonString: String) -> ParsedEvent? {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["event"] as? String else { return nil }
        let message = obj["data"] as? [String: Any] ?? [:]

        if type == "event" {
            guard let name = message["name"] as? String,
                  let event = OpenCovenFeedbackEvent(rawValue: name) else { return nil }
            return ParsedEvent(event: event, data: message["payload"] as? [String: Any] ?? [:])
        }

        guard let event = OpenCovenFeedbackEvent(rawValue: type) else { return nil }
        var payload = message
        payload.removeValue(forKey: "type")
        return ParsedEvent(event: event, data: payload)
    }

    // MARK: - Bridge script

    /// Injected at document start. Defines `window.__quackbackNative.dispatch` so
    /// the widget routes outbound messages to the native message handler instead
    /// of `window.parent.postMessage`.
    static var bridgeScript: String {
        """
        (function () {
          function dispatch(type, message) {
            var payload = JSON.stringify({ event: type, data: message });
            window.webkit.messageHandlers.quackback.postMessage(payload);
          }
          window.__quackbackNative = { dispatch: dispatch };
        })();
        """
    }

    private static func json(_ dict: [String: String]) -> String {
        let d = try! JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        return String(data: d, encoding: .utf8)!
    }
}
