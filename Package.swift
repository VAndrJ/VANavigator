// swift-tools-version:6.2

import PackageDescription

let settings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
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
