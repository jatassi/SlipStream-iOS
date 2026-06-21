// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "FeatureLibrary",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "FeatureLibrary", targets: ["FeatureLibrary"])
  ],
  dependencies: [
    .package(path: "../SlipStreamKit"),
    .package(path: "../DesignSystem"),
  ],
  targets: [
    .target(
      name: "FeatureLibrary",
      dependencies: ["SlipStreamKit", "DesignSystem"]
    )
  ]
)
