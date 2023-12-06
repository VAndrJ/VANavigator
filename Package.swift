// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "VANavigator",
    platforms: [
        .iOS(.v13),
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
            path: "VANavigator/Classes"
        ),
    ]
)
