// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zest",
    platforms: [
        .macOS("15.0")  // macOS 15 minimum for Apple Translation framework
    ],
    products: [
        .executable(
            name: "Zest",
            targets: ["ZestApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.30.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", from: "2.30.0")
    ],
    targets: [
        .executableTarget(
            name: "ZestApp",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm")
            ],
            path: "Sources",
            exclude: ["Info.plist", "Zest.entitlements"],
            linkerSettings: [
                .linkedFramework("QuickLook"),
                .linkedFramework("IOKit"),
                .linkedFramework("Translation"),
                .unsafeFlags(["-L/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/17/lib/darwin"]),
                .linkedLibrary("clang_rt.profile_osx")
            ]
        ),
        .testTarget(
            name: "ZestTests",
            dependencies: ["ZestApp"],
            path: "Tests",
            exclude: ["MLX"]
        ),
        .testTarget(
            name: "MLXLLMTests",
            dependencies: [],
            path: "Tests/MLX"
        )
    ]
)
