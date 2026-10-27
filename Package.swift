// swift-tools-version: 5.9
// Menu bar app. Build it with ./build.sh (no Xcode needed).
import PackageDescription

let package = Package(
    name: "MyContributions",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MyContributions",
            path: ".",
            exclude: ["MenuBar/Info.plist", "README.md", "build.sh", "build"],
            sources: ["Shared", "MenuBar"]
        ),
    ]
)
