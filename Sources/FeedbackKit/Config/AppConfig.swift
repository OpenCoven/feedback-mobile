import Foundation

public struct AppConfig: Sendable {
    public let instanceURL: URL

    public init(instanceURL: URL) {
        self.instanceURL = instanceURL
    }
}
