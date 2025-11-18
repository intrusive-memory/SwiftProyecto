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
        .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", branch: "development")
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
