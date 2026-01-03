// swift-tools-version:6.2

import PackageDescription

let settings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .defaultIsolation(MainActor.self),
]

let package = Package(
    name: "VANavigator",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "VANavigator",
            targets: ["VANavigator"]
        )
    ],
    targets: [
        .target(
            name: "VANavigator",
            path: "VANavigator/Classes",
            swiftSettings: settings
        )
    ],
    swiftLanguageModes: [.v6]
)
