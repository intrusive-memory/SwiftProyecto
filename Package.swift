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
    ],
    dependencies: [
        .package(url: "https://github.com/marcprux/universal.git", from: "5.0.5")
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
        .testTarget(
            name: "SwiftProyectoTests",
            dependencies: ["SwiftProyecto"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
