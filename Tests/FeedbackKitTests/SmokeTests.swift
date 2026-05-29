@testable import FeedbackKit
import XCTest

final class SmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertEqual(FeedbackKit.name, "FeedbackKit")
    }
}
