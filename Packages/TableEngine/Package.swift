// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TableEngine",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "TableEngine", targets: ["TableEngine"])
    ],
    targets: [
        .target(
            name: "TableEngine",
            path: "Sources"
        )
    ]
)
