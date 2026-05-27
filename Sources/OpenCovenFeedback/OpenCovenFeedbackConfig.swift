import Foundation

public enum OpenCovenFeedbackTheme: String, Sendable {
    case light, dark
    case system = "user"
}

public enum OpenCovenFeedbackPosition: Sendable {
    case bottomRight, bottomLeft
}

public struct OpenCovenFeedbackConfig: Sendable {
    public let instanceUrl: URL
    public let theme: OpenCovenFeedbackTheme
    public let placement: OpenCovenFeedbackPosition
    public let locale: String?

    public init(
        instanceUrl: URL,
        theme: OpenCovenFeedbackTheme = .system,
        placement: OpenCovenFeedbackPosition = .bottomRight,
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
