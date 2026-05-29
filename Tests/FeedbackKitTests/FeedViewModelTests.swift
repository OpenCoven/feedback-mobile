@testable import FeedbackKit
import XCTest

@MainActor
final class FeedViewModelTests: XCTestCase {
    func testLoadPopulatesPostsAndClearsLoading() async {
        let api = MockFeedbackAPI()
        api.posts = [PostSummary(id: "post_1", title: "A", voteCount: 5, statusId: nil, boardId: "b1", createdAt: .init(), hasVoted: false)]
        let vm = FeedViewModel(api: api, cache: ContentCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
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
        let emptyCache = ContentCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let vm = FeedViewModel(api: FailingAPI(), cache: emptyCache)
        await vm.load()
        XCTAssertTrue(vm.posts.isEmpty)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    func testCacheFallbackYieldsCachedPostsAndNoError() async throws {
        // Pre-populate a temp cache with one post
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = ContentCache(directory: dir)
        let cachedPost = PostSummary(id: "cached_1", title: "Cached", voteCount: 2, statusId: nil, boardId: "b1", createdAt: Date(timeIntervalSince1970: 0), hasVoted: false)
        try cache.save([cachedPost], as: "feed")

        final class FailingAPI: MockFeedbackAPI {
            override func listPosts(boardId: String?, sort: PostSort, cursor: String?) async throws -> Page<PostSummary> {
                throw APIError.transport("offline")
            }
        }
        let vm = FeedViewModel(api: FailingAPI(), cache: cache)
        await vm.load()
        XCTAssertEqual(vm.posts.map(\.id), ["cached_1"])
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }
}
