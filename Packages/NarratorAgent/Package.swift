// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NarratorAgent",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "NarratorAgent", targets: ["NarratorAgent"])
    ],
    dependencies: [
        .package(path: "../RPGEngine")
    ],
    targets: [
        .target(
            name: "NarratorAgent",
            dependencies: [
                "RPGEngine"
            ],
            path: "Sources"
        )
    ]
)
