// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "SlipStreamKit",
  platforms: [.iOS(.v26), .macOS(.v14)],
  products: [
    .library(name: "SlipStreamKit", targets: ["SlipStreamKit"])
  ],
  targets: [
    .target(name: "SlipStreamKit"),
    .testTarget(
      name: "SlipStreamKitTests",
      dependencies: ["SlipStreamKit"],
      resources: [.copy("Contract/portal.ts")]
    ),
  ]
)
