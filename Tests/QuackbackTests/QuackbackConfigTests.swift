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

    func testCustomValues() {
        let c = QuackbackConfig(
            appId: "my-app", baseURL: URL(string: "https://fb.example.com")!,
            theme: .dark, position: .bottomLeft, buttonColor: "#FF0000", locale: "fr"
        )
        XCTAssertEqual(c.appId, "my-app")
        XCTAssertEqual(c.theme, .dark)
        XCTAssertEqual(c.position, .bottomLeft)
        XCTAssertEqual(c.buttonColor, "#FF0000")
        XCTAssertEqual(c.locale, "fr")
    }

    func testThemeRawValues() {
        XCTAssertEqual(QuackbackTheme.light.rawValue, "light")
        XCTAssertEqual(QuackbackTheme.dark.rawValue, "dark")
        XCTAssertEqual(QuackbackTheme.system.rawValue, "user")
    }

    func testWidgetURLPreservesHost() {
        let c = QuackbackConfig(appId: "test", baseURL: URL(string: "https://custom.domain.com")!)
        XCTAssertEqual(c.widgetURL.host, "custom.domain.com")
        XCTAssertEqual(c.widgetURL.scheme, "https")
    }

    func testWidgetURLWithPort() {
        let c = QuackbackConfig(appId: "test", baseURL: URL(string: "http://localhost:3000")!)
        let url = c.widgetURL
        XCTAssertEqual(url.port, 3000)
        XCTAssertEqual(url.path, "/widget")
    }
}
