// swift-tools-version:5.8

import PackageDescription

let settings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
    name: "VANavigator",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "VANavigator",
            targets: ["VANavigator"]
        ),
    ],
    targets: [
        .target(
            name: "VANavigator",
            path: "VANavigator/Classes",
            swiftSettings: settings
        ),
    ]
)
