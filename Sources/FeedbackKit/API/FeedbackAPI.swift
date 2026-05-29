import Foundation

public enum PostSort: String, Sendable { case newest, votes }

public protocol FeedbackAPI: Sendable {
    func listPosts(boardId: String?, sort: PostSort, cursor: String?) async throws -> Page<PostSummary>
    func getPost(id: String) async throws -> PostDetail
    func listComments(postId: String) async throws -> [Comment]
    func listBoards() async throws -> [Board]
    func listChangelog(cursor: String?) async throws -> Page<ChangelogEntry>
    func listHelpCategories() async throws -> [HelpCategory]
    func getHelpArticle(slug: String) async throws -> HelpArticle
    func submitPost(boardId: String, title: String, content: String) async throws -> PostSummary
    func vote(postId: String) async throws -> VoteResult
    func addComment(postId: String, content: String, parentId: String?) async throws -> Comment
}
