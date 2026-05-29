import FeedbackKit
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let api: FeedbackAPI
    let auth: AuthStore

    private let tokenStore: KeychainTokenStore

    init() {
        let raw = Bundle.main.object(forInfoDictionaryKey: "FEEDBACK_INSTANCE_URL") as? String
            ?? "http://localhost:3000"
        let instanceURL = URL(string: raw) ?? URL(string: "http://localhost:3000")!

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
