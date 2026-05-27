import XCTest
@testable import OpenCovenFeedback

final class OpenCovenFeedbackConfigTests: XCTestCase {
    func testDefaults() {
        let c = OpenCovenFeedbackConfig(instanceUrl: URL(string: "https://fb.example.com")!)
        XCTAssertEqual(c.theme, .system)
        XCTAssertEqual(c.placement, .bottomRight)
        XCTAssertNil(c.locale)
    }

    func testWidgetURL() {
        let c = OpenCovenFeedbackConfig(instanceUrl: URL(string: "https://fb.example.com")!)
        let url = c.widgetURL
        XCTAssertEqual(url.path, "/widget")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertTrue(items.contains(URLQueryItem(name: "source", value: "native")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "platform", value: "ios")))
    }

    func testCustomValues() {
        let c = OpenCovenFeedbackConfig(
            instanceUrl: URL(string: "https://fb.example.com")!,
            theme: .dark, placement: .bottomLeft, locale: "fr"
        )
        XCTAssertEqual(c.theme, .dark)
        XCTAssertEqual(c.placement, .bottomLeft)
        XCTAssertEqual(c.locale, "fr")
    }

    func testThemeRawValues() {
        XCTAssertEqual(OpenCovenFeedbackTheme.light.rawValue, "light")
        XCTAssertEqual(OpenCovenFeedbackTheme.dark.rawValue, "dark")
        XCTAssertEqual(OpenCovenFeedbackTheme.system.rawValue, "user")
    }

    func testWidgetURLPreservesHost() {
        let c = OpenCovenFeedbackConfig(instanceUrl: URL(string: "https://custom.domain.com")!)
        XCTAssertEqual(c.widgetURL.host, "custom.domain.com")
        XCTAssertEqual(c.widgetURL.scheme, "https")
    }

    func testWidgetURLWithPort() {
        let c = OpenCovenFeedbackConfig(instanceUrl: URL(string: "http://localhost:3000")!)
        let url = c.widgetURL
        XCTAssertEqual(url.port, 3000)
        XCTAssertEqual(url.path, "/widget")
    }
}
