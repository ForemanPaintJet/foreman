// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ForemanThemeCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15),
    ],
    products: [
        .library(
            name: "ForemanThemeCore",
            targets: ["ForemanThemeCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ForemanThemeCore",
            dependencies: []),
        .testTarget(
            name: "ForemanThemeCoreTests",
            dependencies: ["ForemanThemeCore"]),
    ]
)
