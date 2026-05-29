import XCTest
@testable import FeedbackKit

@MainActor
final class SubmitViewModelTests: XCTestCase {
    func testSubmitSucceedsWhenSignedIn() async {
        let api = MockFeedbackAPI()
        let vm = SubmitViewModel(api: api, isSignedIn: { true })
        vm.boardId = "b1"; vm.title = "Bug"; vm.content = "Crashes on launch"
        let ok = await vm.submit()
        XCTAssertTrue(ok)
        XCTAssertEqual(api.submitted?.title, "Bug")
    }
    func testSubmitBlockedWhenSignedOut() async {
        let vm = SubmitViewModel(api: MockFeedbackAPI(), isSignedIn: { false })
        vm.boardId = "b1"; vm.title = "Bug"
        let ok = await vm.submit()
        XCTAssertFalse(ok)
        XCTAssertTrue(vm.needsSignIn)
    }
    func testSubmitValidatesEmptyTitle() async {
        let vm = SubmitViewModel(api: MockFeedbackAPI(), isSignedIn: { true })
        vm.boardId = "b1"; vm.title = "  "
        let ok = await vm.submit()
        XCTAssertFalse(ok)
        XCTAssertEqual(vm.errorMessage, "Title is required.")
    }
}
