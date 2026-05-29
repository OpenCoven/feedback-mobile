import Foundation

/// A specific view the widget can open to, passed to `OpenCovenFeedback.open(view:...)`.
/// Raw values match the canonical `quackback:open` contract.
public enum OpenView: String, Sendable {
    /// Home — boards/feed list.
    case home = "home"
    /// New-post form — pre-fill `title` and/or `board` to prime the submission.
    case newPost = "new-post"
    /// Changelog feed.
    case changelog = "changelog"
    /// Help center.
    case help = "help"
}
