// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RPGEngine",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "RPGEngine", targets: ["RPGEngine"])
    ],
    dependencies: [
        .package(path: "../WorldState"),
        .package(path: "../TableEngine")
    ],
    targets: [
        .target(
            name: "RPGEngine",
            dependencies: [
                "WorldState",
                "TableEngine"
            ],
            path: "Sources"
        )
    ]
)
