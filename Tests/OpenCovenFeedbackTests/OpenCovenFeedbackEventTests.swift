import XCTest
@testable import OpenCovenFeedback

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
        var count = 0
        let token = emitter.on(.submit) { _ in count += 1 }
        emitter.emit(.submit, data: [:]); XCTAssertEqual(count, 1)
        emitter.off(token)
        emitter.emit(.submit, data: [:]); XCTAssertEqual(count, 1)
    }

    func testRemoveAll() {
        let emitter = EventEmitter()
        var count = 0
        emitter.on(.vote) { _ in count += 1 }
        emitter.on(.submit) { _ in count += 1 }
        emitter.emit(.vote, data: [:]); emitter.emit(.submit, data: [:])
        XCTAssertEqual(count, 2)
        emitter.removeAll()
        emitter.emit(.vote, data: [:]); XCTAssertEqual(count, 2)
    }

    func testMultipleListenersSameEvent() {
        let emitter = EventEmitter()
        var count1 = 0, count2 = 0
        emitter.on(.vote) { _ in count1 += 1 }
        emitter.on(.vote) { _ in count2 += 1 }
        emitter.emit(.vote, data: [:])
        XCTAssertEqual(count1, 1)
        XCTAssertEqual(count2, 1)
    }

    func testOffWithNonExistentToken() {
        let emitter = EventEmitter()
        var count = 0
        emitter.on(.vote) { _ in count += 1 }
        emitter.off(EventToken()) // non-existent token
        emitter.emit(.vote, data: [:])
        XCTAssertEqual(count, 1) // listener still fires
    }

    func testEmitWithNoListeners() {
        let emitter = EventEmitter()
        // should not crash
        emitter.emit(.vote, data: ["key": "value"])
    }

    func testRemoveOnlyTargetListener() {
        let emitter = EventEmitter()
        var count1 = 0, count2 = 0
        emitter.on(.vote) { _ in count1 += 1 }
        let token2 = emitter.on(.vote) { _ in count2 += 1 }
        emitter.off(token2)
        emitter.emit(.vote, data: [:])
        XCTAssertEqual(count1, 1)
        XCTAssertEqual(count2, 0)
    }

    func testAllEventTypes() {
        let emitter = EventEmitter()
        var received: [OpenCovenFeedbackEvent] = []
        for event in [OpenCovenFeedbackEvent.ready, .vote, .submit, .close, .navigate] {
            emitter.on(event) { _ in received.append(event) }
            emitter.emit(event, data: [:])
        }
        XCTAssertEqual(received, [.ready, .vote, .submit, .close, .navigate])
    }

    func testEventRawValues() {
        XCTAssertEqual(OpenCovenFeedbackEvent.ready.rawValue, "ready")
        XCTAssertEqual(OpenCovenFeedbackEvent.vote.rawValue, "vote")
        XCTAssertEqual(OpenCovenFeedbackEvent.submit.rawValue, "submit")
        XCTAssertEqual(OpenCovenFeedbackEvent.close.rawValue, "close")
        XCTAssertEqual(OpenCovenFeedbackEvent.navigate.rawValue, "navigate")
    }
}
