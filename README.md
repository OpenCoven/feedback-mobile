# OpenCoven Feedback — iOS SDK

Embed the [OpenCoven Feedback](https://github.com/OpenCoven/feedback) widget in your iOS app with a single floating launcher button or programmatic open/close.

## Requirements

- iOS 15+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the package in Xcode: **File > Add Package Dependencies**, then enter:

```
https://github.com/OpenCoven/feedback-mobile
```

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/OpenCoven/feedback-mobile", from: "1.0.0"),
],
targets: [
    .target(name: "YourApp", dependencies: ["OpenCovenFeedback"]),
]
```

## Quick Start

```swift
import OpenCovenFeedback

// 1. Configure once at app startup
OpenCovenFeedback.configure(OpenCovenFeedbackConfig(
    instanceUrl: URL(string: "https://feedback.yourapp.com")!
))

// 2. Show the floating launcher button
OpenCovenFeedback.showLauncher()

// 3. Or open programmatically
OpenCovenFeedback.open()
```

## Identify users

```swift
// Anonymous
OpenCovenFeedback.identify()

// Known user
OpenCovenFeedback.identify(userId: "u_123", email: "val@example.com", name: "Val")

// SSO token
OpenCovenFeedback.identify(ssoToken: "your-sso-token")
```

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `instanceUrl` | `URL` | required | Your OpenCoven Feedback instance URL |
| `theme` | `OpenCovenFeedbackTheme` | `.system` | `.light`, `.dark`, or `.system` |
| `placement` | `OpenCovenFeedbackPosition` | `.bottomRight` | `.bottomRight` or `.bottomLeft` |
| `locale` | `String?` | `nil` | Override locale, e.g. `"fr"` |

## Events

```swift
let token = OpenCovenFeedback.on(.open) { data in
    print("Widget opened", data)
}

// Remove listener
OpenCovenFeedback.off(token)
```

## Related

- [OpenCoven Feedback (web)](https://github.com/OpenCoven/feedback)
- [Android SDK](https://github.com/OpenCoven/quackback-android)
