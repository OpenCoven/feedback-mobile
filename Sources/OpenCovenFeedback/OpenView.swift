import Foundation

/// A specific view the widget can open to, passed to `OpenCovenFeedback.open(view:...)`.
/// Matches the `quackback:open` contract (`home` | `new-post`); other surfaces
/// (changelog, help) are reached as tabs once the widget is open.
public enum OpenView: String, Sendable {
    /// Home — boards/feed list.
    case home = "home"
    /// New-post form — pre-fill `title` and/or `board` to prime the submission.
    case newPost = "new-post"
}
