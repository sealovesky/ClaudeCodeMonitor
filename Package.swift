// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeCodeMonitor",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCodeMonitor",
            path: "Sources/ClaudeCodeMonitor"
        )
    ]
)
