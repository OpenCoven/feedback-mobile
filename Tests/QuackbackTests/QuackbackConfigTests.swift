import XCTest
@testable import Quackback

final class QuackbackConfigTests: XCTestCase {
    func testDefaults() {
        let c = QuackbackConfig(instanceUrl: URL(string: "https://fb.example.com")!)
        XCTAssertEqual(c.theme, .system)
        XCTAssertEqual(c.placement, .bottomRight)
        XCTAssertNil(c.locale)
    }

    func testWidgetURL() {
        let c = QuackbackConfig(instanceUrl: URL(string: "https://fb.example.com")!)
        let url = c.widgetURL
        XCTAssertEqual(url.path, "/widget")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertTrue(items.contains(URLQueryItem(name: "source", value: "native")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "platform", value: "ios")))
    }

    func testCustomValues() {
        let c = QuackbackConfig(
            instanceUrl: URL(string: "https://fb.example.com")!,
            theme: .dark, placement: .bottomLeft, locale: "fr"
        )
        XCTAssertEqual(c.theme, .dark)
        XCTAssertEqual(c.placement, .bottomLeft)
        XCTAssertEqual(c.locale, "fr")
    }

    func testThemeRawValues() {
        XCTAssertEqual(QuackbackTheme.light.rawValue, "light")
        XCTAssertEqual(QuackbackTheme.dark.rawValue, "dark")
        XCTAssertEqual(QuackbackTheme.system.rawValue, "user")
    }

    func testWidgetURLPreservesHost() {
        let c = QuackbackConfig(instanceUrl: URL(string: "https://custom.domain.com")!)
        XCTAssertEqual(c.widgetURL.host, "custom.domain.com")
        XCTAssertEqual(c.widgetURL.scheme, "https")
    }

    func testWidgetURLWithPort() {
        let c = QuackbackConfig(instanceUrl: URL(string: "http://localhost:3000")!)
        let url = c.widgetURL
        XCTAssertEqual(url.port, 3000)
        XCTAssertEqual(url.path, "/widget")
    }
}
