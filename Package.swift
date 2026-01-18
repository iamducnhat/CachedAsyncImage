// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CachedAsyncImage",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "CachedAsyncImage",
            targets: ["CachedAsyncImage"]
        ),
    ],
    targets: [
        .target(
            name: "CachedAsyncImage",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
