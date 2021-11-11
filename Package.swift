// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

import PackageDescription

let package = Package(
  name: "RKFade",
  platforms: [.iOS("15.0")],
  products: [
    .library(name: "RKFade", targets: ["RKFade"])
  ],
  dependencies: [],
  targets: [
    .target(name: "RKFade", dependencies: [])
  ],
  swiftLanguageVersions: [.v5]
)

