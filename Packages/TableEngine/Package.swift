// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TableEngine",
    platforms: [.iOS(.v26)],
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
