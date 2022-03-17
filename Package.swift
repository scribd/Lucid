// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Lucid",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .watchOS(.v7), .tvOS(.v13)
    ],
    products: [
        .library(name: "Lucid", targets: ["Lucid"]),
        .library(name: "LucidTestKit", targets: ["LucidTestKit"])
    ],
    targets: [
        .target(
            name: "Lucid",
            path: "Lucid"
        ),
        .target(
            name: "LucidTestKit",
            dependencies: ["Lucid"],
            path: "LucidTestKit"
        ),
    ]
)