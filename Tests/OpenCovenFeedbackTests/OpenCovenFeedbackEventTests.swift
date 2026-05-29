@testable import OpenCovenFeedback
import XCTest

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.lock(); value += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}
private final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [OpenCovenFeedbackEvent] = []
    func append(_ e: OpenCovenFeedbackEvent) { lock.lock(); events.append(e); lock.unlock() }
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
        let token = emitter.on(.submit) { _ in counter.increment() }
        emitter.emit(.submit, data: [:]); XCTAssertEqual(counter.count, 1)
        emitter.off(token)
        emitter.emit(.submit, data: [:]); XCTAssertEqual(counter.count, 1)
    }

    func testRemoveAll() {
        let emitter = EventEmitter()
        let counter = Counter()
        emitter.on(.vote) { _ in counter.increment() }
        emitter.on(.submit) { _ in counter.increment() }
        emitter.emit(.vote, data: [:]); emitter.emit(.submit, data: [:])
        XCTAssertEqual(counter.count, 2)
        emitter.removeAll()
        emitter.emit(.vote, data: [:]); XCTAssertEqual(counter.count, 2)
    }

    func testMultipleListenersSameEvent() {
        let emitter = EventEmitter()
        let counter1 = Counter()
        let counter2 = Counter()
        emitter.on(.vote) { _ in counter1.increment() }
        emitter.on(.vote) { _ in counter2.increment() }
        emitter.emit(.vote, data: [:])
        XCTAssertEqual(counter1.count, 1)
        XCTAssertEqual(counter2.count, 1)
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
        let counter1 = Counter()
        let counter2 = Counter()
        emitter.on(.vote) { _ in counter1.increment() }
        let token2 = emitter.on(.vote) { _ in counter2.increment() }
        emitter.off(token2)
        emitter.emit(.vote, data: [:])
        XCTAssertEqual(counter1.count, 1)
        XCTAssertEqual(counter2.count, 0)
    }

    func testAllEventTypes() {
        let emitter = EventEmitter()
        let log = EventLog()
        for event in [OpenCovenFeedbackEvent.ready, .vote, .submit, .close, .navigate] {
            emitter.on(event) { _ in log.append(event) }
            emitter.emit(event, data: [:])
        }
        XCTAssertEqual(log.all, [.ready, .vote, .submit, .close, .navigate])
    }

    func testEventRawValues() {
        XCTAssertEqual(OpenCovenFeedbackEvent.ready.rawValue, "ready")
        XCTAssertEqual(OpenCovenFeedbackEvent.vote.rawValue, "vote")
        XCTAssertEqual(OpenCovenFeedbackEvent.submit.rawValue, "submit")
        XCTAssertEqual(OpenCovenFeedbackEvent.close.rawValue, "close")
        XCTAssertEqual(OpenCovenFeedbackEvent.navigate.rawValue, "navigate")
    }
}
