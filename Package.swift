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
            path: "Sources"
        ),
        .testTarget(
            name: "ZestTests",
            dependencies: ["ZestApp"],
            path: "tests"
        )
    ]
)
