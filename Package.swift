// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "SwiftProyecto",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: [
    .library(
      name: "SwiftProyecto",
      targets: ["SwiftProyecto"]
    ),
    .executable(
      name: "proyecto",
      targets: ["proyecto"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/marcprux/universal.git", from: "5.3.0"),
    .package(url: "https://github.com/intrusive-memory/SwiftBruja.git", from: "1.5.1"),
    .package(url: "https://github.com/intrusive-memory/SwiftAcervo.git", from: "0.7.1"),  // Requires v2 access patterns (withComponentAccess)
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0"),
  ],
  targets: [
    .target(
      name: "SwiftProyecto",
      dependencies: [
        .product(name: "Universal", package: "universal"),
        .product(name: "SwiftAcervo", package: "SwiftAcervo")
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableExperimentalFeature("Lifetimes")
      ]
    ),
    .executableTarget(
      name: "proyecto",
      dependencies: [
        "SwiftProyecto",
        .product(name: "SwiftBruja", package: "SwiftBruja"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableExperimentalFeature("Lifetimes")
      ]
    ),
    .testTarget(
      name: "SwiftProyectoTests",
      dependencies: [
        "SwiftProyecto",
        .product(name: "SwiftBruja", package: "SwiftBruja"),
        .product(name: "SwiftAcervo", package: "SwiftAcervo")
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableExperimentalFeature("Lifetimes")
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
