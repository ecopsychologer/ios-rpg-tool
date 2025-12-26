// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WorldState",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "WorldState", targets: ["WorldState"])
    ],
    targets: [
        .target(
            name: "WorldState",
            path: "Sources"
        )
    ]
)
