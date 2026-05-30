import FeedbackKit
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let api: FeedbackAPI
    let auth: AuthStore

    private let tokenStore: KeychainTokenStore

    init() {
        // Dev default is localhost; point at a live instance by setting
        // FEEDBACK_INSTANCE_URL in FeedbackApp/FeedbackApp.xcconfig (gitignored).
        // An unset value resolves to "" or an unsubstituted literal, so only a
        // well-formed URL with a scheme and host overrides the localhost default.
        let configured = (Bundle.main.object(forInfoDictionaryKey: "FEEDBACK_INSTANCE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = configured.flatMap { URL(string: $0) }
        let instanceURL = (parsed?.scheme != nil && parsed?.host != nil)
            ? parsed!
            : URL(string: "http://localhost:3000")!

        let store = KeychainTokenStore()
        let authService = HTTPAuthService(baseURL: instanceURL)
        let authStore = AuthStore(service: authService, tokenStore: store)

        self.tokenStore = store
        self.auth = authStore
        self.api = HTTPFeedbackAPI(
            baseURL: instanceURL,
            tokenProvider: { store.token }
        )
    }
}
