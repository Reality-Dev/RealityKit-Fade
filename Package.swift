// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RKFade",
    platforms: [.iOS("15.0"), .macOS("12.0")],
    products: [
        .library(name: "RKFade", targets: ["RKFade"]),
    ],
    dependencies: [
        .package(name: "RKUtilities", url: "https://github.com/Reality-Dev/RealityKit-Utilities", from: "1.1.01"),
    ],
    targets: [
        .target(name: "RKFade",
                dependencies: [.product(name: "RKUtilities", package: "RKUtilities")]),
    ],
    swiftLanguageVersions: [.v5]
)
