import Foundation

// NOTE: The endpoint paths below (/api/auth/email-otp/send-verification-otp and
// /api/auth/sign-in/email-otp) and the "token" field in the sign-in response are
// assumptions based on the better-auth `emailOTP` plugin convention. Confirm these
// against a live instance before shipping — AuthService/AuthStore interfaces won't change.
public final class HTTPAuthService: AuthService, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    public init(baseURL: URL, session: URLSession = .shared) { self.baseURL = baseURL; self.session = session }

    public func sendOTP(email: String) async throws {
        _ = try await post("/api/auth/email-otp/send-verification-otp", body: ["email": email, "type": "sign-in"])
    }

    public func verifyOTP(email: String, code: String) async throws -> String {
        let data = try await post("/api/auth/sign-in/email-otp", body: ["email": email, "otp": code])
        struct R: Decodable { let token: String }
        guard let token = try? JSONDecoder().decode(R.self, from: data).token else {
            throw APIError.decoding("No token in sign-in response")
        }
        return token
    }

    private func post(_ path: String, body: [String: String]) async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? -1, code: nil)
        }
        return data
    }
}
