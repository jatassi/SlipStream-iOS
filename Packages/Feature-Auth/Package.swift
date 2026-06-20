// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "FeatureAuth",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "FeatureAuth", targets: ["FeatureAuth"])
  ],
  dependencies: [
    .package(path: "../SlipStreamKit")
  ],
  targets: [
    .target(
      name: "FeatureAuth",
      dependencies: ["SlipStreamKit"]
    )
  ]
)
