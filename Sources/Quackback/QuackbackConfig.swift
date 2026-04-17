import Foundation

public enum QuackbackTheme: String, Sendable {
    case light, dark
    case system = "user"
}

public enum QuackbackPosition: Sendable {
    case bottomRight, bottomLeft
}

public struct QuackbackConfig: Sendable {
    public let instanceUrl: URL
    public let theme: QuackbackTheme
    public let placement: QuackbackPosition
    public let locale: String?

    public init(
        instanceUrl: URL,
        theme: QuackbackTheme = .system,
        placement: QuackbackPosition = .bottomRight,
        locale: String? = nil
    ) {
        self.instanceUrl = instanceUrl
        self.theme = theme
        self.placement = placement
        self.locale = locale
    }

    public var widgetURL: URL {
        var c = URLComponents(url: instanceUrl, resolvingAgainstBaseURL: false)!
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
