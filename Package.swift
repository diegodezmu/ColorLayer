// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumaVeil",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "LumaVeil",
            targets: ["LumaVeil"]
        ),
    ],
    targets: [
        .target(
            name: "LumaVeil",
            path: "LumaVeil",
            exclude: [
                "Assets.xcassets",
                "LumaVeilApp.swift",
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
            name: "LumaVeilTests",
            dependencies: ["LumaVeil"],
            path: "LumaVeilTests"
        ),
    ]
)
