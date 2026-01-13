// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YTMusicPlayer",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/alexeichhorn/YouTubeKit.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "YTMusicPlayer",
            dependencies: ["YouTubeKit"],
            path: "YTMusicPlayer"
        )
    ]
)
