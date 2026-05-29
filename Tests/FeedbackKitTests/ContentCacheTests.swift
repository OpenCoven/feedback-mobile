import XCTest
@testable import FeedbackKit

final class ContentCacheTests: XCTestCase {
    func testRoundTripsPosts() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = ContentCache(directory: dir)
        // Use a date with millisecond precision so the ISO-8601 encode/decode round-trip is exact.
        let posts = [PostSummary(id: "post_1", title: "A", voteCount: 1, statusId: nil, boardId: "b1", createdAt: Date(timeIntervalSince1970: 1_700_000_000.123), hasVoted: false)]
        try cache.save(posts, as: "feed")
        let loaded: [PostSummary] = try cache.load("feed", as: [PostSummary].self)
        XCTAssertEqual(loaded, posts)
    }
    func testLoadMissingThrows() {
        let cache = ContentCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        XCTAssertThrowsError(try cache.load("nope", as: [PostSummary].self))
    }
}
