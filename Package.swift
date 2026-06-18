// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "termdown",
    platforms: [
        .macOS(.v13),   // raised from .v12: Chroma (syntax highlighting) requires macOS 13+
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/onevcat/Chroma.git", from: "0.3.1"),
    ],
    targets: [
        .target(
            name: "termdownCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Chroma", package: "Chroma"),
            ],
            path: "Sources/termdownCore"
        ),
        .executableTarget(
            name: "termdown",
            dependencies: [
                .target(name: "termdownCore"),
            ],
            path: "Sources/termdown"
        ),
        .testTarget(
            name: "termdownCoreTests",
            dependencies: [
                .target(name: "termdownCore"),
            ],
            path: "Tests/termdownCoreTests"
        ),
        .testTarget(
            name: "termdownTests",
            dependencies: [
                .target(name: "termdown"),
                .target(name: "termdownCore"),
            ],
            path: "Tests/termdownTests"
        ),
    ]
)
