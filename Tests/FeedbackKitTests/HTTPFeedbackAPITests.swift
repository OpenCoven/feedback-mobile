@testable import FeedbackKit
import XCTest

class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
    override func startLoading() {
        let (resp, data) = StubURLProtocol.handler!(request)
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class HTTPFeedbackAPITests: XCTestCase {
    private func makeAPI(token: String? = nil) -> HTTPFeedbackAPI {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: cfg)
        return HTTPFeedbackAPI(baseURL: URL(string: "https://fb.example.com")!,
                               session: session, tokenProvider: { token })
    }

    func testListPostsParsesEnvelope() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/public/v1/posts")
            let body = #"{"data":[{"id":"post_1","title":"A","voteCount":2,"statusId":null,"boardId":"b1","createdAt":"2026-01-01T00:00:00.000Z","hasVoted":false}],"meta":{"pagination":{"cursor":null,"hasMore":false}}}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }
        let page = try await makeAPI().listPosts(boardId: nil, sort: .newest, cursor: nil)
        XCTAssertEqual(page.data.first?.id, "post_1")
    }

    func testVoteSendsBearerAndMapsUnauthorized() async {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
            return (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"error":{"code":"UNAUTHORIZED","message":"x"}}"#.utf8))
        }
        do { _ = try await makeAPI(token: "tok").vote(postId: "post_1"); XCTFail("expected throw") } catch {
            XCTAssertEqual(error as? APIError, .unauthorized)
        }
    }
}
