import Foundation

enum JSBridge {
    struct ParsedEvent { let event: QuackbackEvent; let data: [String: Any] }

    static func initCommand(config: QuackbackConfig) -> String {
        var p: [String: String] = ["appId": config.appId, "theme": config.theme.rawValue]
        if let l = config.locale { p["locale"] = l }
        return "window.postMessage({type:'quackback:init',data:\(json(p))},'*');"
    }

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

    static func openCommand(board: String?) -> String {
        guard let b = board else { return "window.postMessage({type:'quackback:open'},'*');" }
        return "window.postMessage({type:'quackback:open',data:\(json(["board": b]))},'*');"
    }

    static func logoutCommand() -> String { "window.postMessage({type:'quackback:identify',data:null},'*');" }

    static func parseEvent(_ jsonString: String) -> ParsedEvent? {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = obj["event"] as? String,
              let event = QuackbackEvent(rawValue: name) else { return nil }
        var eventData: [String: Any] = [:]
        if let d = obj["data"] as? [String: Any] {
            eventData = (d["payload"] as? [String: Any]) ?? d
        }
        return ParsedEvent(event: event, data: eventData)
    }

    static var bridgeScript: String {
        """
        (function(){
          var dispatch=function(e,d){
            var m=JSON.stringify({event:e,data:d});
            window.webkit.messageHandlers.quackback.postMessage(m);
          };
          window.__quackbackNative={dispatch:dispatch};
        })();
        """
    }

    private static func json(_ dict: [String: String]) -> String {
        let d = try! JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        return String(data: d, encoding: .utf8)!
    }
}
