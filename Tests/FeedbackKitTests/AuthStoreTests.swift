@testable import FeedbackKit
import XCTest

final class StubAuthService: AuthService, @unchecked Sendable {
    var sentTo: String?
    var tokenToReturn = "session_tok"
    var sendError: Error?
    func sendOTP(email: String) async throws {
        if let sendError { throw sendError }
        sentTo = email
    }
    func verifyOTP(email: String, code: String) async throws -> String { tokenToReturn }
}

@MainActor
final class AuthStoreTests: XCTestCase {
    func testSignInStoresTokenAndFlipsState() async {
        let store = InMemoryTokenStore()
        let auth = AuthStore(service: StubAuthService(), tokenStore: store)
        XCTAssertFalse(auth.isSignedIn)
        try? await auth.requestCode(email: "v@x.com")
        await auth.verify(email: "v@x.com", code: "123456")
        XCTAssertTrue(auth.isSignedIn)
        XCTAssertEqual(store.token, "session_tok")
    }

    func testSignOutClearsToken() async {
        let store = InMemoryTokenStore(token: "old")
        let auth = AuthStore(service: StubAuthService(), tokenStore: store)
        XCTAssertTrue(auth.isSignedIn)
        auth.signOut()
        XCTAssertFalse(auth.isSignedIn)
        XCTAssertNil(store.token)
    }

    func testRequestCodeFailureSetsErrorMessageAndRethrows() async {
        let service = StubAuthService()
        service.sendError = APIError.transport("offline")
        let auth = AuthStore(service: service, tokenStore: InMemoryTokenStore())

        do {
            try await auth.requestCode(email: "v@x.com")
            XCTFail("Expected requestCode to throw")
        } catch {
            XCTAssertEqual(auth.errorMessage, "Couldn't send a code. Please try again.")
        }
    }
}
