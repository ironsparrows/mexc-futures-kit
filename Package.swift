// swift-tools-version: 6.4
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "mexc-futures-kit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "MexcFuturesKit",
            targets: ["MexcFuturesKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.16.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.103.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.15.1"),
        .package(url: "https://github.com/ibireme/yyjson.git", from: "0.13.0"),
    ],
    targets: [
        .target(
            name: "MexcFuturesKit",
            dependencies: [
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "yyjson", package: "yyjson"),
            ],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "MexcFuturesKitTests",
            dependencies: [
                "MexcFuturesKit",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
            ],
            swiftSettings: swiftSettings,
        ),
    ]
)
