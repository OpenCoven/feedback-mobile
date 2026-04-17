import Foundation

public enum QuackbackTheme: String, Sendable {
    case light, dark
    case system = "user"
}

public enum QuackbackPosition: Sendable {
    case bottomRight, bottomLeft
}

public struct QuackbackConfig: Sendable {
    public let appUrl: URL
    public let theme: QuackbackTheme
    public let placement: QuackbackPosition
    public let buttonColor: String?
    public let locale: String?

    public init(
        appUrl: URL,
        theme: QuackbackTheme = .system,
        placement: QuackbackPosition = .bottomRight,
        buttonColor: String? = nil,
        locale: String? = nil
    ) {
        self.appUrl = appUrl
        self.theme = theme
        self.placement = placement
        self.buttonColor = buttonColor
        self.locale = locale
    }

    public var widgetURL: URL {
        var c = URLComponents(url: appUrl, resolvingAgainstBaseURL: false)!
        c.path = "/widget"
        c.queryItems = [
            URLQueryItem(name: "source", value: "native"),
            URLQueryItem(name: "platform", value: "ios"),
        ]
        if let locale = locale {
            c.queryItems?.append(URLQueryItem(name: "locale", value: locale))
        }
        return c.url!
    }
}
