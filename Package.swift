// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TacticsSwiftSDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "Tactics", targets: ["Tactics"]),
        .executable(name: "tactics-swift", targets: ["tactics-swift"]),
    ],
    dependencies: [
        // 0.2.0: per-game `evaluate(game:)` without PGN output; 0.2.1: faster game trees.
        .package(url: "https://github.com/NSStudent/CQLSwiftSDK.git", from: "0.2.1"),
        .package(url: "https://github.com/NSStudent/fischer-core.git", from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "Tactics",
            dependencies: [
                .product(name: "CQL", package: "CQLSwiftSDK"),
                .product(name: "FischerCore", package: "fischer-core"),
            ],
            resources: [.copy("Resources/Motifs")]
        ),
        .executableTarget(
            name: "tactics-swift",
            dependencies: ["Tactics"]
        ),
        .testTarget(
            name: "TacticsTests",
            dependencies: [
                "Tactics",
                .product(name: "FischerCore", package: "fischer-core"),
            ]
        ),
    ]
)
