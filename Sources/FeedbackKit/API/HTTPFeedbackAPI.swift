import Foundation

private struct _ErrorBody: Decodable {
    struct Inner: Decodable { let code: String? }
    let error: Inner?
}

public final class HTTPFeedbackAPI: FeedbackAPI, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: @Sendable () -> String?

    public init(baseURL: URL,
                session: URLSession = .shared,
                tokenProvider: @escaping @Sendable () -> String?) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    // MARK: - FeedbackAPI

    public func listPosts(boardId: String?, sort: PostSort, cursor: String?) async throws -> Page<PostSummary> {
        var query: [(String, String)] = [("sort", sort.rawValue)]
        if let boardId { query.append(("boardId", boardId)) }
        if let cursor { query.append(("cursor", cursor)) }
        let req = request(path: "/api/public/v1/posts", method: "GET", query: query)
        return try await send(req)
    }

    public func getPost(id: String) async throws -> PostDetail {
        let req = request(path: "/api/public/v1/posts/\(id)", method: "GET", query: [])
        let envelope: Envelope<PostDetail> = try await send(req)
        return envelope.data
    }

    public func listComments(postId: String) async throws -> [Comment] {
        let req = request(path: "/api/public/v1/posts/\(postId)/comments", method: "GET", query: [])
        let envelope: Envelope<[Comment]> = try await send(req)
        return envelope.data
    }

    public func listBoards() async throws -> [Board] {
        let req = request(path: "/api/public/v1/boards", method: "GET", query: [])
        let envelope: Envelope<[Board]> = try await send(req)
        return envelope.data
    }

    public func listChangelog(cursor: String?) async throws -> Page<ChangelogEntry> {
        var query: [(String, String)] = []
        if let cursor { query.append(("cursor", cursor)) }
        let req = request(path: "/api/public/v1/changelog", method: "GET", query: query)
        return try await send(req)
    }

    public func listHelpCategories() async throws -> [HelpCategory] {
        let req = request(path: "/api/public/v1/help/categories", method: "GET", query: [])
        let envelope: Envelope<[HelpCategory]> = try await send(req)
        return envelope.data
    }

    public func getHelpArticle(slug: String) async throws -> HelpArticle {
        let req = request(path: "/api/public/v1/help/articles/\(slug)", method: "GET", query: [])
        let envelope: Envelope<HelpArticle> = try await send(req)
        return envelope.data
    }

    public func submitPost(boardId: String, title: String, content: String) async throws -> PostSummary {
        var req = request(path: "/api/public/v1/posts", method: "POST", query: [])
        let body: [String: String] = ["boardId": boardId, "title": title, "content": content]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let envelope: Envelope<PostSummary> = try await send(req)
        return envelope.data
    }

    public func vote(postId: String) async throws -> VoteResult {
        var req = request(path: "/api/public/v1/posts/\(postId)/vote", method: "POST", query: [])
        req.httpBody = Data()
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let envelope: Envelope<VoteResult> = try await send(req)
        return envelope.data
    }

    public func addComment(postId: String, content: String, parentId: String?) async throws -> Comment {
        var req = request(path: "/api/public/v1/posts/\(postId)/comments", method: "POST", query: [])
        var body: [String: String] = ["content": content]
        if let parentId { body["parentId"] = parentId }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let envelope: Envelope<Comment> = try await send(req)
        return envelope.data
    }

    // MARK: - Private helpers

    private func request(path: String, method: String, query: [(String, String)]) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        // appendingPathComponent may double-encode slashes; rebuild the path directly
        components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        if let token = tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func send<R: Decodable>(_ request: URLRequest) async throws -> R {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Non-HTTP response")
        }

        let status = http.statusCode
        if (200..<300).contains(status) {
            do {
                return try JSONDecoder.feedback.decode(R.self, from: data)
            } catch {
                throw APIError.decoding(error.localizedDescription)
            }
        }

        switch status {
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        default:
            // Attempt to extract error.code from the response body
            let code = (try? JSONDecoder().decode(_ErrorBody.self, from: data))?.error?.code
            throw APIError.server(status: status, code: code)
        }
    }
}
