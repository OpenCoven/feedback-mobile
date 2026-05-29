import XCTest
@testable import FeedbackKit

@MainActor
final class PostDetailViewModelTests: XCTestCase {
    func testLoadFetchesPostAndComments() async {
        let api = MockFeedbackAPI()
        let vm = PostDetailViewModel(postId: "post_1", api: api, isSignedIn: { true })
        await vm.load()
        XCTAssertEqual(vm.post?.id, "post_1")
        XCTAssertNotNil(vm.comments)
    }

    func testVoteUpdatesCountWhenSignedIn() async {
        let api = MockFeedbackAPI()
        api.voteResult = VoteResult(voted: true, voteCount: 9)
        let vm = PostDetailViewModel(postId: "post_1", api: api, isSignedIn: { true })
        await vm.load()
        await vm.toggleVote()
        XCTAssertEqual(vm.post?.voteCount, 9)
        XCTAssertEqual(vm.post?.hasVoted, true)
        XCTAssertFalse(vm.needsSignIn)
    }

    func testVoteWhenSignedOutRequestsSignIn() async {
        let vm = PostDetailViewModel(postId: "post_1", api: MockFeedbackAPI(), isSignedIn: { false })
        await vm.load()
        await vm.toggleVote()
        XCTAssertTrue(vm.needsSignIn)
    }
}
