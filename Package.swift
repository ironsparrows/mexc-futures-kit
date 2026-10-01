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
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", branch: "master"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.16.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.103.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.15.1"),
    ],
    targets: [
        .target(
            name: "MexcFuturesKit",
            dependencies: [
                .product(name: "SwiftyJSON", package: "SwiftyJSON"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "MexcFuturesKitTests",
            dependencies: ["MexcFuturesKit"],
            swiftSettings: swiftSettings,
        ),
    ]
)
