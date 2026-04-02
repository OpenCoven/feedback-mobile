// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Quackback",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Quackback", targets: ["Quackback"]),
    ],
    targets: [
        .target(name: "Quackback", path: "Sources/Quackback"),
        .testTarget(name: "QuackbackTests", dependencies: ["Quackback"], path: "Tests/QuackbackTests"),
    ]
)
