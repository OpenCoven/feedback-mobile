@testable import FeedbackKit
import XCTest

final class ProtocolConformanceTests: XCTestCase {

    func testMockConformsToFeedbackAPI() async throws {
        // Assigning to the protocol type proves conformance at compile time.
        let api: FeedbackAPI = MockFeedbackAPI()
        let page = try await api.listPosts(boardId: nil, sort: .newest, cursor: nil)
        XCTAssertEqual(page.data.count, 0)
    }

    func testShouldUnauthorizeThrowsOnWrite() async {
        let mock = MockFeedbackAPI()
        mock.shouldUnauthorize = true

        do {
            _ = try await mock.submitPost(boardId: "b", title: "T", content: "C")
            XCTFail("Expected unauthorized error")
        } catch APIError.unauthorized {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRecordsSubmittedInputs() async throws {
        let mock = MockFeedbackAPI()
        _ = try await mock.submitPost(boardId: "b1", title: "My Post", content: "Body")
        XCTAssertEqual(mock.submitted?.boardId, "b1")
        XCTAssertEqual(mock.submitted?.title, "My Post")
        XCTAssertEqual(mock.submitted?.content, "Body")
    }

    func testRecordsVotePostId() async throws {
        let mock = MockFeedbackAPI()
        let result = try await mock.vote(postId: "post_42")
        XCTAssertEqual(mock.votedPostId, "post_42")
        XCTAssertTrue(result.voted)
        XCTAssertEqual(result.voteCount, 1)
    }

    func testRecordsAddedComment() async throws {
        let mock = MockFeedbackAPI()
        let comment = try await mock.addComment(postId: "post_1", content: "Nice!", parentId: nil)
        XCTAssertEqual(mock.addedComment?.postId, "post_1")
        XCTAssertEqual(mock.addedComment?.content, "Nice!")
        XCTAssertNil(mock.addedComment?.parentId)
        XCTAssertEqual(comment.content, "Nice!")
    }
}
