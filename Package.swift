// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenCovenFeedback",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "OpenCovenFeedback", targets: ["OpenCovenFeedback"]),
        .library(name: "FeedbackKit", targets: ["FeedbackKit"]),
    ],
    targets: [
        .target(name: "OpenCovenFeedback", path: "Sources/OpenCovenFeedback"),
        .testTarget(name: "OpenCovenFeedbackTests", dependencies: ["OpenCovenFeedback"], path: "Tests/OpenCovenFeedbackTests"),
        .target(name: "FeedbackKit", path: "Sources/FeedbackKit"),
        .testTarget(name: "FeedbackKitTests", dependencies: ["FeedbackKit"], path: "Tests/FeedbackKitTests"),
    ]
)
