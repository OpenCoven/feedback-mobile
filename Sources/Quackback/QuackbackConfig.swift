import Foundation

public enum QuackbackTheme: String, Sendable {
    case light, dark
    case system = "user"
}

public enum QuackbackPosition: Sendable {
    case bottomRight, bottomLeft
}

public struct QuackbackConfig: Sendable {
    public let appId: String
    public let baseURL: URL
    public let theme: QuackbackTheme
    public let position: QuackbackPosition
    public let buttonColor: String?
    public let locale: String?

    public init(
        appId: String, baseURL: URL,
        theme: QuackbackTheme = .system, position: QuackbackPosition = .bottomRight,
        buttonColor: String? = nil, locale: String? = nil
    ) {
        self.appId = appId; self.baseURL = baseURL; self.theme = theme
        self.position = position; self.buttonColor = buttonColor; self.locale = locale
    }

    public var widgetURL: URL {
        var c = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        c.path = "/widget"
        c.queryItems = [
            URLQueryItem(name: "source", value: "native"),
            URLQueryItem(name: "platform", value: "ios"),
        ]
        return c.url!
    }
}
