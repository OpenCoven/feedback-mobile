import XCTest
@testable import Quackback

final class QuackbackConfigTests: XCTestCase {
    func testDefaults() {
        let c = QuackbackConfig(appId: "test", baseURL: URL(string: "https://fb.example.com")!)
        XCTAssertEqual(c.theme, .system)
        XCTAssertEqual(c.position, .bottomRight)
        XCTAssertNil(c.buttonColor)
        XCTAssertNil(c.locale)
    }

    func testWidgetURL() {
        let c = QuackbackConfig(appId: "test", baseURL: URL(string: "https://fb.example.com")!)
        let url = c.widgetURL
        XCTAssertEqual(url.path, "/widget")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertTrue(items.contains(URLQueryItem(name: "source", value: "native")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "platform", value: "ios")))
    }
}
