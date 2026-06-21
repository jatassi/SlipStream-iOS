// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "DesignSystem",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "DesignSystem", targets: ["DesignSystem"])
  ],
  dependencies: [
    .package(path: "../SlipStreamKit"),
    .package(url: "https://github.com/kean/Nuke", from: "12.8.0"),
  ],
  targets: [
    .target(
      name: "DesignSystem",
      dependencies: [
        "SlipStreamKit",
        .product(name: "NukeUI", package: "Nuke"),
        .product(name: "Nuke", package: "Nuke"),
      ],
      resources: [.copy("Resources/Fonts/InterVariable.ttf")]
    )
  ]
)
