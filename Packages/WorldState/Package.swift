// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WorldState",
    platforms: [.iOS(.v26)],
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
