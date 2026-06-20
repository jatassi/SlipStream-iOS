// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "FeatureShell",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "FeatureShell", targets: ["FeatureShell"])
  ],
  dependencies: [
    .package(path: "../SlipStreamKit")
  ],
  targets: [
    .target(
      name: "FeatureShell",
      dependencies: ["SlipStreamKit"]
    )
  ]
)
