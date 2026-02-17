// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zest",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Zest",
            targets: ["ZestApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ZestApp",
            dependencies: [],
            path: "Sources",
            exclude: ["Info.plist", "Zest.entitlements"]
        ),
        .testTarget(
            name: "ZestTests",
            dependencies: ["ZestApp"],
            path: "tests"
        )
    ]
)
