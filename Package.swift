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
        // Will add SwiftCompartido dependency when we need PROJECT.md parsing
    ],
    targets: [
        .target(
            name: "SwiftProyecto",
            dependencies: []
        ),
        .testTarget(
            name: "SwiftProyectoTests",
            dependencies: ["SwiftProyecto"]
        ),
    ]
)
