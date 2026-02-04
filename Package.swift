// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoopMaker",
    platforms: [
        .macOS(.v15)  // macOS 26 (Tahoe)
    ],
    products: [
        .executable(
            name: "LoopMaker",
            targets: ["LoopMaker"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LoopMaker",
            dependencies: [],
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
