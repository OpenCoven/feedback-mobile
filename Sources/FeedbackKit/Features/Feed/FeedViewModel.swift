import Foundation

@MainActor
public final class FeedViewModel: ObservableObject {
    @Published public private(set) var posts: [PostSummary] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let api: FeedbackAPI
    public var boardId: String?
    public var sort: PostSort = .newest

    public init(api: FeedbackAPI) { self.api = api }

    public func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let page = try await api.listPosts(boardId: boardId, sort: sort, cursor: nil)
            posts = page.data
        } catch {
            errorMessage = Self.message(for: error)
        }
        isLoading = false
    }

    static func message(for error: Error) -> String {
        switch error {
        case APIError.transport: return "You appear to be offline. Pull to retry."
        case APIError.rateLimited: return "Too many requests. Try again shortly."
        default: return "Something went wrong. Please try again."
        }
    }
}
