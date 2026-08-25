// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnimalBuddy",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "AnimalBuddy", targets: ["AnimalBuddy"])],
    targets: [
        .executableTarget(name: "AnimalBuddy", path: "Sources/AnimalBuddy"),
        .testTarget(name: "AnimalBuddyTests", dependencies: ["AnimalBuddy"], path: "Tests/AnimalBuddyTests")
    ]
)
