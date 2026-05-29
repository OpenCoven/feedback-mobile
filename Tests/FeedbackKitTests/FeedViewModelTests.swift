import XCTest
@testable import FeedbackKit

@MainActor
final class FeedViewModelTests: XCTestCase {
    func testLoadPopulatesPostsAndClearsLoading() async {
        let api = MockFeedbackAPI()
        api.posts = [PostSummary(id: "post_1", title: "A", voteCount: 5, statusId: nil, boardId: "b1", createdAt: .init(), hasVoted: false)]
        let vm = FeedViewModel(api: api)
        await vm.load()
        XCTAssertEqual(vm.posts.map(\.id), ["post_1"])
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testLoadFailureSetsErrorMessage() async {
        final class FailingAPI: MockFeedbackAPI {
            override func listPosts(boardId: String?, sort: PostSort, cursor: String?) async throws -> Page<PostSummary> {
                throw APIError.transport("offline")
            }
        }
        let vm = FeedViewModel(api: FailingAPI())
        await vm.load()
        XCTAssertTrue(vm.posts.isEmpty)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }
}
