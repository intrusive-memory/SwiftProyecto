// swift-tools-version: 6.2

import Foundation
import PackageDescription

// In CI we always pin to released remotes. Locally, prefer a sibling checkout
// at ../<name> if present so in-flight changes can be exercised end-to-end
// without publishing a release. Falls back to the remote pin if the sibling
// directory is missing, so fresh clones still build.
let useLocalSiblings = ProcessInfo.processInfo.environment["CI"] != "true"

func sibling(_ name: String, remote: String, from version: Version) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, .upToNextMajor(from: version))
}

/// Same sibling-priority pattern as ``sibling(_:remote:from:)`` but pins to a
/// remote branch when no local sibling exists. Use only when a temporary
/// pre-release dependency on a feature branch is required; switch back to the
/// version-pinned ``sibling(_:remote:from:)`` once the upstream tags a release.
func sibling(_ name: String, remote: String, branch: String) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, branch: branch)
}

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
    .package(url: "https://github.com/marcprux/universal.git", .upToNextMajor(from: "5.3.0")),
    sibling(
      "SwiftBruja",
      remote: "https://github.com/intrusive-memory/SwiftBruja.git",
      from: "1.6.1"),
    sibling(
      "SwiftAcervo",
      remote: "https://github.com/intrusive-memory/SwiftAcervo.git",
      from: "0.11.1"),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.7.1")),
  ],
  targets: [
    .target(
      name: "SwiftProyecto",
      dependencies: [
        .product(name: "Universal", package: "universal"),
        .product(name: "SwiftAcervo", package: "SwiftAcervo"),
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
        .product(name: "SwiftBruja", package: "SwiftBruja"),
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
        .product(name: "SwiftBruja", package: "SwiftBruja"),
        .product(name: "SwiftAcervo", package: "SwiftAcervo"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableExperimentalFeature("Lifetimes"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
