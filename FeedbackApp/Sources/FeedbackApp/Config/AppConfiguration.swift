import Foundation
import OpenCovenFeedback

/// Central app configuration. Reads `FEEDBACK_INSTANCE_URL` from the
/// environment / xcconfig at build time so no secrets land in source.
final class AppConfiguration: ObservableObject {
    static let shared = AppConfiguration()

    /// The OpenCoven Feedback instance URL. Populated from xcconfig /
    /// environment variable FEEDBACK_INSTANCE_URL; falls back to localhost
    /// for development builds only.
    private(set) var instanceURL: URL

    init() {
        // Read from compile-time xcconfig (injected via Info.plist key) or
        // from environment for CI/test runs.
        let raw = Bundle.main.object(forInfoDictionaryKey: "FEEDBACK_INSTANCE_URL") as? String
            ?? ProcessInfo.processInfo.environment["FEEDBACK_INSTANCE_URL"]
            ?? "http://localhost:3000"
        self.instanceURL = URL(string: raw) ?? URL(string: "http://localhost:3000")!
    }

    /// Called once at app startup. Configures the SDK but does NOT
    /// call identify — that happens after authentication.
    func setup() {
        OpenCovenFeedback.configure(
            OpenCovenFeedbackConfig(
                instanceUrl: instanceURL,
                theme: .system,
                placement: .bottomRight
            )
        )
        setupEventListeners()
    }

    private func setupEventListeners() {
        OpenCovenFeedback.on(.postCreated) { data in
            // Forward to analytics layer when integrated
            print("[Feedback] post created:", data)
        }
        OpenCovenFeedback.on(.vote) { data in
            print("[Feedback] vote:", data)
        }
        OpenCovenFeedback.on(.open) { _ in
            print("[Feedback] widget opened")
        }
        OpenCovenFeedback.on(.close) { _ in
            print("[Feedback] widget closed")
        }
    }
}
