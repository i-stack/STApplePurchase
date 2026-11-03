// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "STApplePurchase",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "STApplePurchase",
            targets: ["STApplePurchase"]
        ),
    ],
    targets: [
        .target(
            name: "STApplePurchase",
            dependencies: [],
            path: "Sources/STApplePurchase"
        ),
        .testTarget(
            name: "STApplePurchaseTests",
            dependencies: [
                .target(name: "STApplePurchase")
            ],
            path: "Tests/STApplePurchaseTests",
            resources: [
                .copy("Resources/STApplePurchaseTests.storekit")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
