@testable import OpenCovenFeedback
import XCTest

/// Thread-safe counter so it can be captured by the `@Sendable` event handler
/// without mutating captured local state.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.lock(); value += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}

/// Thread-safe ordered log of received events, for the same reason as `Counter`.
private final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [OpenCovenFeedbackEvent] = []
    func append(_ event: OpenCovenFeedbackEvent) { lock.lock(); events.append(event); lock.unlock() }
    var all: [OpenCovenFeedbackEvent] { lock.lock(); defer { lock.unlock() }; return events }
}

final class OpenCovenFeedbackEventTests: XCTestCase {
    func testAddAndFire() {
        let emitter = EventEmitter()
        let exp = expectation(description: "fired")
        emitter.on(.vote) { data in
            XCTAssertEqual(data["postId"] as? String, "post_abc")
            exp.fulfill()
        }
        emitter.emit(.vote, data: ["postId": "post_abc"])
        waitForExpectations(timeout: 1)
    }

    func testRemove() {
        let emitter = EventEmitter()
        let counter = Counter()
        let token = emitter.on(.postCreated) { _ in counter.increment() }
        emitter.emit(.postCreated, data: [:]); XCTAssertEqual(counter.count, 1)
        emitter.off(token)
        emitter.emit(.postCreated, data: [:]); XCTAssertEqual(counter.count, 1)
    }

    func testRemoveAll() {
        let emitter = EventEmitter()
        let counter = Counter()
        emitter.on(.vote) { _ in counter.increment() }
        emitter.on(.postCreated) { _ in counter.increment() }
        emitter.emit(.vote, data: [:]); emitter.emit(.postCreated, data: [:])
        XCTAssertEqual(counter.count, 2)
        emitter.removeAll()
        emitter.emit(.vote, data: [:]); XCTAssertEqual(counter.count, 2)
    }

    func testMultipleListenersSameEvent() {
        let emitter = EventEmitter()
        let first = Counter(), second = Counter()
        emitter.on(.vote) { _ in first.increment() }
        emitter.on(.vote) { _ in second.increment() }
        emitter.emit(.vote, data: [:])
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 1)
    }

    func testOffWithNonExistentToken() {
        let emitter = EventEmitter()
        let counter = Counter()
        emitter.on(.vote) { _ in counter.increment() }
        emitter.off(EventToken()) // non-existent token
        emitter.emit(.vote, data: [:])
        XCTAssertEqual(counter.count, 1) // listener still fires
    }

    func testEmitWithNoListeners() {
        let emitter = EventEmitter()
        // should not crash
        emitter.emit(.vote, data: ["key": "value"])
    }

    func testRemoveOnlyTargetListener() {
        let emitter = EventEmitter()
        let first = Counter(), second = Counter()
        emitter.on(.vote) { _ in first.increment() }
        let token2 = emitter.on(.vote) { _ in second.increment() }
        emitter.off(token2)
        emitter.emit(.vote, data: [:])
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 0)
    }

    func testAllEventTypes() {
        let emitter = EventEmitter()
        let log = EventLog()
        let all: [OpenCovenFeedbackEvent] = [
            .ready, .open, .close, .postCreated, .vote, .commentCreated,
            .identify, .navigate, .identifyResult, .authChange,
        ]
        for event in all {
            emitter.on(event) { _ in log.append(event) }
            emitter.emit(event, data: [:])
        }
        XCTAssertEqual(log.all, all)
    }

    func testEventRawValuesMatchContract() {
        XCTAssertEqual(OpenCovenFeedbackEvent.ready.rawValue, "ready")
        XCTAssertEqual(OpenCovenFeedbackEvent.open.rawValue, "open")
        XCTAssertEqual(OpenCovenFeedbackEvent.close.rawValue, "close")
        XCTAssertEqual(OpenCovenFeedbackEvent.postCreated.rawValue, "post:created")
        XCTAssertEqual(OpenCovenFeedbackEvent.vote.rawValue, "vote")
        XCTAssertEqual(OpenCovenFeedbackEvent.commentCreated.rawValue, "comment:created")
        XCTAssertEqual(OpenCovenFeedbackEvent.identify.rawValue, "identify")
        XCTAssertEqual(OpenCovenFeedbackEvent.navigate.rawValue, "navigate")
        XCTAssertEqual(OpenCovenFeedbackEvent.identifyResult.rawValue, "identify-result")
        XCTAssertEqual(OpenCovenFeedbackEvent.authChange.rawValue, "auth-change")
    }
}
