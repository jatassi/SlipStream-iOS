// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "FeatureAuth",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "FeatureAuth", targets: ["FeatureAuth"])
  ],
  dependencies: [
    .package(path: "../SlipStreamKit"),
    .package(path: "../DesignSystem"),
  ],
  targets: [
    .target(
      name: "FeatureAuth",
      dependencies: ["SlipStreamKit", "DesignSystem"]
    )
  ]
)
