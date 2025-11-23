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
        .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", branch: "development"),
        .package(url: "https://github.com/groue/GRMustache.swift.git", from: "7.0.0" )
    ],
    targets: [
        .target(
            name: "SwiftProyecto",
            dependencies: ["SwiftCompartido"]
        ),
        .testTarget(
            name: "SwiftProyectoTests",
            dependencies: ["SwiftProyecto"]
        ),
    ]
)
