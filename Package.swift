// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "dmenu-spotlight",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "dmenu-spotlight"),
        .testTarget(name: "dmenu-spotlightTests", dependencies: ["dmenu-spotlight"]),
    ]
)
