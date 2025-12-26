// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RPGEngine",
    platforms: [.iOS("26.0")],
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
