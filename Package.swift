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
    dependencies: [
        // MLX Swift - Apple Silicon ML framework
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.21.0"),
    ],
    targets: [
        .executableTarget(
            name: "LoopMaker",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
                .product(name: "MLXFFT", package: "mlx-swift"),
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
