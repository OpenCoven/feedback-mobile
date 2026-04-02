# Quackback iOS SDK

Embed the [Quackback](https://quackback.io) feedback widget in your iOS app with a single floating trigger button or programmatic open/close.

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

// 2. Identify the current user (optional)
Quackback.identify(userId: "user_123", email: "user@example.com", name: "Jane Smith")

// 3. Show the floating trigger button
Quackback.showTrigger()
```

## API

| Method | Description |
|--------|-------------|
| `Quackback.configure(_ config: QuackbackConfig)` | Set up the SDK. Call once at app launch before any other method. |
| `Quackback.identify(userId:email:name:avatarURL:)` | Associate the current user with feedback. |
| `Quackback.identify(ssoToken:)` | Identify using a server-issued SSO token. |
| `Quackback.logout()` | Clear the current user identity. |
| `Quackback.open(board:)` | Open the feedback panel, optionally on a specific board slug. |
| `Quackback.close()` | Dismiss the feedback panel. |
| `Quackback.showTrigger()` | Add the floating trigger button to the key window. |
| `Quackback.hideTrigger()` | Remove the floating trigger button. |
| `Quackback.on(_:handler:) -> EventToken` | Subscribe to a widget event. Returns a token for removal. |
| `Quackback.off(_ token: EventToken)` | Unsubscribe a previously registered listener. |
| `Quackback.destroy()` | Tear down the SDK entirely (removes WebView, trigger, and all listeners). |

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
