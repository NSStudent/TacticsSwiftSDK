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
        // Needs the next CQLSwiftSDK release (per-game `evaluate(game:)` without
        // PGN output or a large-stack thread). Until it is published, build
        // against a sibling checkout; then switch to:
        // .package(url: "https://github.com/NSStudent/CQLSwiftSDK.git", from: "<version>"),
        .package(path: "../CQLSwiftSDK"),
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
