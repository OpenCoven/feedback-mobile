@testable import FeedbackKit
import Foundation

// MARK: - MockFeedbackAPI

struct SubmittedPost {
    var boardId: String
    var title: String
    var content: String
}

struct AddedComment {
    var postId: String
    var content: String
    var parentId: String?
}

// Non-final so subclasses can override individual methods to inject failures.
class MockFeedbackAPI: @unchecked Sendable, FeedbackAPI {

    // MARK: Canned data (mutable so tests can configure per-scenario)

    var posts: [PostSummary] = []
    var postDetail = PostDetail(
        id: "post_1",
        title: "Test Post",
        content: "Content",
        voteCount: 0,
        statusId: nil,
        boardId: "board_1",
        createdAt: Date(timeIntervalSince1970: 0),
        hasVoted: false
    )
    var comments: [Comment] = []
    var boards: [Board] = []
    var changelogEntries: [ChangelogEntry] = []
    var helpCategories: [HelpCategory] = []
    var helpArticle = HelpArticle(
        id: "article_1",
        slug: "getting-started",
        title: "Getting Started",
        content: "Welcome.",
        categoryId: "cat_1"
    )
    var voteResult = VoteResult(voted: true, voteCount: 1)

    // MARK: Failure injection

    var shouldUnauthorize = false

    // MARK: Recorded inputs

    var submitted: SubmittedPost?
    var votedPostId: String?
    var addedComment: AddedComment?

    // MARK: FeedbackAPI conformance

    func listPosts(boardId: String?, sort: PostSort, cursor: String?) async throws -> Page<PostSummary> {
        Page(data: posts, meta: nil)
    }

    func getPost(id: String) async throws -> PostDetail {
        postDetail
    }

    func listComments(postId: String) async throws -> [Comment] {
        comments
    }

    func listBoards() async throws -> [Board] {
        boards
    }

    func listChangelog(cursor: String?) async throws -> Page<ChangelogEntry> {
        Page(data: changelogEntries, meta: nil)
    }

    func listHelpCategories() async throws -> [HelpCategory] {
        helpCategories
    }

    func getHelpArticle(slug: String) async throws -> HelpArticle {
        helpArticle
    }

    func submitPost(boardId: String, title: String, content: String) async throws -> PostSummary {
        if shouldUnauthorize { throw APIError.unauthorized }
        submitted = SubmittedPost(boardId: boardId, title: title, content: content)
        let post = PostSummary(
            id: "post_new",
            title: title,
            voteCount: 0,
            statusId: nil,
            boardId: boardId,
            createdAt: Date(timeIntervalSince1970: 0),
            hasVoted: false
        )
        return post
    }

    func vote(postId: String) async throws -> VoteResult {
        if shouldUnauthorize { throw APIError.unauthorized }
        votedPostId = postId
        return voteResult
    }

    func addComment(postId: String, content: String, parentId: String?) async throws -> Comment {
        if shouldUnauthorize { throw APIError.unauthorized }
        addedComment = AddedComment(postId: postId, content: content, parentId: parentId)
        return Comment(
            id: "comment_new",
            content: content,
            authorName: "Test User",
            createdAt: Date(timeIntervalSince1970: 0),
            replies: []
        )
    }
}
