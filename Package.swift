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
            exclude: ["Info.plist", "Zest.entitlements"],
            linkerSettings: [
                .linkedFramework("QuickLook"),
                .linkedFramework("IOKit"),
                .unsafeFlags(["-L/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/17/lib/darwin"]),
                .linkedLibrary("clang_rt.profile_osx")
            ]
        ),
        .testTarget(
            name: "ZestTests",
            dependencies: ["ZestApp"],
            path: "Tests"
        )
    ]
)
