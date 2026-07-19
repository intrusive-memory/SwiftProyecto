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
    .library(
      name: "ProjectBrowser",
      targets: ["ProjectBrowser"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/marcprux/universal.git", .upToNextMajor(from: "5.3.0")),
    .package(
      url: "https://github.com/intrusive-memory/SwiftAcervo.git", .upToNextMajor(from: "0.24.1")),
    .package(
      url: "https://github.com/intrusive-memory/SwiftCompartido.git", .upToNextMajor(from: "7.2.4")),
    // NOTE: SwiftBruja is deliberately NOT a dependency. `proyecto roles` runs
    // its casting/role extraction on-device via Apple's Foundation Models
    // (guided generation), so the library and CLI stay free of SwiftBruja's
    // MLX + swift-transformers stack. Pulling SwiftBruja in here drags a second
    // `Tokenizers` target into every downstream consumer's graph (colliding
    // with mlx-audio-swift's swift-tokenizers) and breaks library consumers
    // like SwiftEchada. Keep it out.
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.7.1")),
  ],
  targets: [
    .target(
      name: "SwiftProyecto",
      dependencies: [
        .product(name: "Universal", package: "universal"),
        .product(name: "SwiftAcervo", package: "SwiftAcervo"),
        .product(name: "SwiftCompartido", package: "SwiftCompartido"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableExperimentalFeature("Lifetimes"),
      ]
    ),
    .executableTarget(
      name: "proyecto",
      dependencies: [
        "SwiftProyecto",
        .product(name: "SwiftAcervo", package: "SwiftAcervo"),
        .product(name: "SwiftCompartido", package: "SwiftCompartido"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableExperimentalFeature("Lifetimes"),
      ]
    ),
    .testTarget(
      name: "SwiftProyectoTests",
      dependencies: [
        "SwiftProyecto",
        .product(name: "SwiftAcervo", package: "SwiftAcervo"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableExperimentalFeature("Lifetimes"),
      ]
    ),
    .target(
      name: "ProjectBrowser",
      dependencies: [],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableExperimentalFeature("Lifetimes"),
      ]
    ),
    .testTarget(
      name: "ProjectBrowserTests",
      dependencies: [
        "ProjectBrowser"
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableExperimentalFeature("Lifetimes"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
