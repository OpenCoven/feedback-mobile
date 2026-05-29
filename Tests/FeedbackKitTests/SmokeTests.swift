import XCTest
@testable import FeedbackKit

final class SmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertEqual(FeedbackKit.name, "FeedbackKit")
    }
}
