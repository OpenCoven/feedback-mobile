import Foundation

public enum OpenCovenFeedbackEvent: String, Sendable {
    case ready, vote, submit, close, navigate
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
