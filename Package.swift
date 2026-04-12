// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ColorLayer",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "ColorLayer",
            targets: ["ColorLayer"]
        ),
    ],
    targets: [
        .target(
            name: "ColorLayer",
            path: "ColorLayer",
            exclude: [
                "Assets.xcassets",
                "ColorLayerApp.swift",
                "Overlay",
                "Resources",
                "UI",
            ],
            sources: [
                "AppState.swift",
                "DisplayTransferController.swift",
                "Models",
                "Persistence",
            ]
        ),
        .testTarget(
            name: "ColorLayerTests",
            dependencies: ["ColorLayer"],
            path: "ColorLayerTests"
        ),
    ]
)
