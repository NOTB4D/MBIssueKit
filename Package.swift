// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MBIssueKit",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "MBIssueKit",
            targets: ["MBIssueKit"]
        ),
    ],
    targets: [
        .target(
            name: "MBIssueKit"
        ),
        .testTarget(
            name: "MBIssueKitTests",
            dependencies: ["MBIssueKit"]
        ),
    ]
)
