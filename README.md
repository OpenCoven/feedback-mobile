# Quackback iOS SDK

Embed the [Quackback](https://quackback.io) feedback widget in your iOS app with a single floating launcher button or programmatic open/close.

## Requirements

- iOS 15+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the package in Xcode: **File > Add Package Dependencies**, then enter the repository URL:

```
https://github.com/quackback/quackback-ios
```

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/quackback/quackback-ios", from: "1.0.0"),
],
targets: [
    .target(name: "YourApp", dependencies: ["Quackback"]),
]
```

## Quick Start

```swift
import Quackback

// 1. Configure once at app startup
Quackback.configure(QuackbackConfig(
    appId: "your-app-id",
    baseURL: URL(string: "https://feedback.yourapp.com")!
))

// 2. Identify the current user
Quackback.identify(userId: "user_123", email: "user@example.com", name: "Jane Smith")
// or, with a server-signed token (recommended for production):
Quackback.identify(ssoToken: fetchedSsoToken)
// or, for unauthenticated visitors:
Quackback.identify()

// 3. Show the floating launcher button
Quackback.showLauncher()

// 4. On logout
Quackback.logout()
```

Turn on **Verified identity only** in **Admin → Settings → Widget** to require `ssoToken` for every identified user. See the [Identify users guide](https://quackback.io/docs/widget/identify-users) for JWT claims and server examples.

## API

| Method | Description |
|--------|-------------|
| `Quackback.configure(_ config: QuackbackConfig, identity: Identity? = nil)` | Set up the SDK. Pass an optional `Identity` to bundle identification into the same call. |
| `Quackback.identify()` | Start an anonymous session. The widget prompts for an email inline the first time the user posts. |
| `Quackback.identify(userId:email:name:avatarURL:)` | Identify the current user with their details. Simplest option, works out of the box. |
| `Quackback.identify(ssoToken:)` | Identify the current user with a server-signed JWT. Blocks impersonation. |
| `Quackback.logout()` | Clear the current user identity. |

### Identity

Pass an `Identity` value to `configure(_:identity:)` to bundle identification at setup time:

```swift
Quackback.configure(config, identity: .user(id: "u_123", email: "a@b.com", name: "Ada"))
Quackback.configure(config, identity: .ssoToken("jwt..."))
// Omit the `identity` parameter for anonymous sessions — it's the default.
```
| `Quackback.open(board:)` | Open the feedback panel, optionally on a specific board slug. |
| `Quackback.close()` | Dismiss the feedback panel. |
| `Quackback.showLauncher()` | Add the floating launcher button to the key window. |
| `Quackback.hideLauncher()` | Remove the floating launcher button. |
| `Quackback.on(_:handler:) -> EventToken` | Subscribe to a widget event. Returns a token for removal. |
| `Quackback.off(_ token: EventToken)` | Unsubscribe a previously registered listener. |
| `Quackback.destroy()` | Tear down the SDK entirely (removes WebView, launcher, and all listeners). |

### QuackbackConfig

```swift
QuackbackConfig(
    appId: String,                         // required — your Quackback app ID
    baseURL: URL,                          // required — your Quackback instance URL
    theme: QuackbackTheme = .system,       // .light | .dark | .system
    position: QuackbackPosition = .bottomRight, // .bottomRight | .bottomLeft
    buttonColor: String? = nil,            // hex color e.g. "#6366F1"
    locale: String? = nil                  // BCP-47 locale e.g. "fr", "de"
)
```

## Events

Subscribe to events emitted by the widget:

```swift
let token = Quackback.on(.vote) { data in
    print("User voted on post:", data["postId"] ?? "")
}

// Remove the listener when no longer needed
Quackback.off(token)
```

| Event | Payload keys | Description |
|-------|-------------|-------------|
| `.ready` | — | Widget has loaded and initialised. |
| `.vote` | `postId`, `direction` | User voted on a post. |
| `.submit` | `postId`, `title` | User submitted new feedback. |
| `.close` | — | User closed the panel (panel dismisses automatically). |
| `.navigate` | `board`, `postId` | User navigated within the widget. |

## License

MIT
