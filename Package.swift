// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoopMaker",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "LoopMaker",
            targets: ["LoopMaker"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "LoopMaker",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "LoopMaker",
            exclude: ["Info.plist", "LoopMaker.entitlements", "Resources"]
        ),
        .testTarget(
            name: "LoopMakerTests",
            dependencies: ["LoopMaker"],
            path: "LoopMakerTests"
        ),
    ]
)
