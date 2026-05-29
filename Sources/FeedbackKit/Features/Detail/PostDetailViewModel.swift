import Foundation

@MainActor
public final class PostDetailViewModel: ObservableObject {
    @Published public private(set) var post: PostDetail?
    @Published public private(set) var comments: [Comment] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public var needsSignIn = false

    private let postId: String
    private let api: FeedbackAPI
    private let isSignedIn: () -> Bool

    public init(postId: String, api: FeedbackAPI, isSignedIn: @escaping () -> Bool) {
        self.postId = postId
        self.api = api
        self.isSignedIn = isSignedIn
    }

    public func load() async {
        isLoading = true; errorMessage = nil
        do {
            async let p = api.getPost(id: postId)
            async let c = api.listComments(postId: postId)
            post = try await p
            comments = try await c
        } catch {
            errorMessage = FeedViewModel.message(for: error)
        }
        isLoading = false
    }

public func toggleVote() async {
    needsSignIn = false
    guard isSignedIn() else { needsSignIn = true; return }
    do {
            let result = try await api.vote(postId: postId)
            if let current = post {
                post = PostDetail(
                    id: current.id,
                    title: current.title,
                    content: current.content,
                    voteCount: result.voteCount,
                    statusId: current.statusId,
                    boardId: current.boardId,
                    createdAt: current.createdAt,
                    hasVoted: result.voted
                )
            }
        } catch APIError.unauthorized {
            needsSignIn = true
        } catch {
            errorMessage = FeedViewModel.message(for: error)
        }
    }

public func addComment(_ text: String) async {
    needsSignIn = false
    guard isSignedIn() else { needsSignIn = true; return }
    do {
            let comment = try await api.addComment(postId: postId, content: text, parentId: nil)
            comments.insert(comment, at: 0)
        } catch APIError.unauthorized {
            needsSignIn = true
        } catch {
            errorMessage = FeedViewModel.message(for: error)
        }
    }
}
