// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftProyecto",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
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
        .package(url: "https://github.com/marcprux/universal.git", from: "5.0.5"),
        .package(path: "../SwiftBruja"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "SwiftProyecto",
            dependencies: [
                .product(name: "Universal", package: "universal")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
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
            ]
        ),
        .testTarget(
            name: "SwiftProyectoTests",
            dependencies: ["SwiftProyecto"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "ProyectoIntegrationTests",
            dependencies: ["SwiftProyecto"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
