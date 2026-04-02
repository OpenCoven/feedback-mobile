import XCTest
@testable import Quackback

final class QuackbackEventTests: XCTestCase {
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
}
