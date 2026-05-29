@testable import FeedbackKit
import XCTest

final class HTTPAuthServiceTests: XCTestCase {
    private func make() -> HTTPAuthService {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        return HTTPAuthService(baseURL: URL(string: "https://fb.example.com")!, session: URLSession(configuration: cfg))
    }
    func testVerifyReturnsToken() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/auth/sign-in/email-otp")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"token":"sess_123","user":{"id":"u1"}}"#.utf8))
        }
        let token = try await make().verifyOTP(email: "v@x.com", code: "123456")
        XCTAssertEqual(token, "sess_123")
    }
}
