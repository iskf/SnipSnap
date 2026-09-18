// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnipSnap",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SnipSnap",
            targets: ["SnipSnap"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SnipSnap",
            dependencies: [],
            path: "Sources/SnipSnap"
        )
    ]
)
