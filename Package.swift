// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Scrollercoaster",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "Scrollercoaster",
            path: "Sources/Scrollercoaster"
        )
    ]
)
