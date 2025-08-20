// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebRTCCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "WebRTCCore",
            targets: ["WebRTCCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/stasel/WebRTC", from: "137.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.20.2"
        ),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "WebRTCCore",
            dependencies: [
                .product(name: "WebRTC", package: "WebRTC"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            exclude: [
                "TCA/WebRTCView.swift",
            ]
        ),
        .testTarget(
            name: "WebRTCCoreTests",
            dependencies: [
                "WebRTCCore",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ],
//            exclude: [
//                "WebRTCFeatureTests.swift",
//            ]
        ),
    ]
)
