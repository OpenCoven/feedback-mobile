import Foundation

/// Events surfaced by the widget. Raw values match the canonical wire contract
/// (`lib/shared/widget/types.ts` in OpenCoven/feedback).
public enum OpenCovenFeedbackEvent: String, Sendable {
    /// Widget finished loading — emitted once per session.
    case ready
    /// Widget panel opened.
    case open
    /// Widget panel closed.
    case close
    /// A post was created. Payload: `id`, `title`, `board`, `statusId`.
    case postCreated = "post:created"
    /// A vote toggled. Payload: `postId`, `voted`, `voteCount`.
    case vote
    /// A comment was created. Payload: `postId`, `commentId`, `parentId`.
    case commentCreated = "comment:created"
    /// Identify resolved inside the widget. Payload: `success`, `user`, `anonymous`, `error`.
    case identify
    /// The widget navigated. Payload: `url`.
    case navigate
    /// Result of an `identify` command. Payload: `success`, `user`, `error`.
    case identifyResult = "identify-result"
    /// The signed-in user changed. Payload: `user`.
    case authChange = "auth-change"
}

public struct EventToken: Hashable, Sendable { let id = UUID() }
public typealias EventListener = @Sendable ([String: Any]) -> Void

final class EventEmitter: @unchecked Sendable {
    private let lock = NSLock()
    private var listeners: [OpenCovenFeedbackEvent: [(token: EventToken, handler: EventListener)]] = [:]

    @discardableResult
    func on(_ event: OpenCovenFeedbackEvent, handler: @escaping EventListener) -> EventToken {
        let token = EventToken()
        lock.lock(); listeners[event, default: []].append((token, handler)); lock.unlock()
        return token
    }

    func off(_ token: EventToken) {
        lock.lock()
        for event in listeners.keys { listeners[event]?.removeAll { $0.token == token } }
        lock.unlock()
    }

    func emit(_ event: OpenCovenFeedbackEvent, data: [String: Any]) {
        lock.lock(); let handlers = listeners[event] ?? []; lock.unlock()
        for (_, handler) in handlers { handler(data) }
    }

    func removeAll() { lock.lock(); listeners.removeAll(); lock.unlock() }
}
