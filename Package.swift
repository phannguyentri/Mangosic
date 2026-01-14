// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mangosic",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/alexeichhorn/YouTubeKit.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "Mangosic",
            dependencies: ["YouTubeKit"],
            path: "Mangosic"
        )
    ]
)
