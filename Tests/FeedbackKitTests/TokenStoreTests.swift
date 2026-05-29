import XCTest
@testable import FeedbackKit

final class TokenStoreTests: XCTestCase {
    func testInMemoryStoreRoundTrips() {
        let store = InMemoryTokenStore()
        XCTAssertNil(store.token)
        store.token = "abc"
        XCTAssertEqual(store.token, "abc")
        store.token = nil
        XCTAssertNil(store.token)
    }
}
