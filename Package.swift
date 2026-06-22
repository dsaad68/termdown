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
        // Self-contained native Swift port of mermaid-ascii (MIT, © 2023
        // Alexander Grooff). Has no dependency on termdownCore so it stays
        // independently testable/reusable.
        .target(
            name: "MermaidRenderer",
            path: "Sources/MermaidRenderer",
            exclude: ["NOTICE"]
        ),
        .target(
            name: "termdownCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Chroma", package: "Chroma"),
                .target(name: "MermaidRenderer"),
            ],
            path: "Sources/termdownCore"
        ),
        .executableTarget(
            name: "termdown",
            dependencies: [
                .target(name: "termdownCore"),
                .target(name: "MermaidRenderer"),
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
            name: "MermaidRendererTests",
            dependencies: [
                .target(name: "MermaidRenderer"),
            ],
            path: "Tests/MermaidRendererTests",
            exclude: ["testdata"]
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
