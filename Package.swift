// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MBIssueKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "MBIssueKit",
            type: .dynamic,
            targets: ["MBIssueKit"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/mobven/MBAsyncNetworkingXCFramework.git",
            exact: "1.0.0"
        ),
        .package(
            url: "https://github.com/mobven/MobkitCoreXCFramework.git",
            exact: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "MBIssueKit",
            dependencies: [
                .product(
                    name: "MBAsyncNetworking",
                    package: "MBAsyncNetworkingXCFramework",
                    condition: .when(platforms: [.iOS])
                ),
                .product(
                    name: "MobKitCore",
                    package: "MobkitCoreXCFramework",
                    condition: .when(platforms: [.iOS])
                ),
            ]
        ),
        .testTarget(
            name: "MBIssueKitTests",
            dependencies: ["MBIssueKit"]
        ),
    ]
)
