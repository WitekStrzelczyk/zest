// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zest",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(
            name: "Zest",
            targets: ["ZestApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ZestApp",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources",
            exclude: ["Info.plist", "Zest.entitlements"],
            linkerSettings: [
                .linkedFramework("QuickLook"),
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "ZestTests",
            dependencies: ["ZestApp"],
            path: "Tests",
            exclude: ["Fixtures"]
        )
    ]
)
