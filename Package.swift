// swift-tools-version:6.2

import PackageDescription

let settings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .defaultIsolation(MainActor.self),
    .define("VANAVIGATOR_DEINIT_WORKAROUND", .when(configuration: .debug)),
]

let package = Package(
    name: "VANavigator",
    platforms: [
        .iOS(.v15)
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
