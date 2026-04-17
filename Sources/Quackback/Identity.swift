import Foundation

/// The identity to pass to `Quackback.configure(_:identity:)` so the widget
/// can associate activity with the current user at setup time.
///
/// Equivalent to calling `Quackback.identify(...)` immediately after configure.
/// Omit the `identity` parameter entirely for anonymous sessions — the widget
/// starts anonymous by default.
public enum Identity {
    /// Identify the current user by their details. Simplest option — works out of the box.
    /// Turn on "Verified identity only" in Admin → Settings → Widget to require `.ssoToken` instead.
    case user(id: String, email: String, name: String? = nil, avatarURL: String? = nil)

    /// Identify the current user with a server-signed JWT. Blocks impersonation.
    case ssoToken(String)
}
