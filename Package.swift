// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "SwiftDB",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(
      name: "SwiftDB",
      targets: ["SwiftDB"]
    ),
  ],
  targets: [
    .target(
      name: "SwiftDB"
    ),
    .testTarget(
      name: "SwiftDBTests",
      dependencies: ["SwiftDB"]
    ),
  ]
)

for target in package.targets {
  var settings = target.swiftSettings ?? []
  settings.append(.enableExperimentalFeature("StrictConcurrency"))
  settings.append(.enableUpcomingFeature("ExistentialAny"))
  target.swiftSettings = settings
}
