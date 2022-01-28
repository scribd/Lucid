// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Lucid",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(name: "Lucid", targets: ["Lucid"]),
        .library(name: "LucidTestKit", targets: ["LucidTestKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/DeclarativeHub/ReactiveKit.git", .exact("3.18.2"))
    ],
    targets: [
        .target(
            name: "Lucid",
            dependencies: ["ReactiveKit"],
            path: "Lucid"
        ),
        .target(
            name: "LucidTestKit",
            dependencies: ["Lucid"],
            path: "LucidTestKit"
        ),
        .testTarget(
            name: "LucidTests",
            dependencies: ["Lucid", "LucidTestKit"],
            path: "LucidTests"
        )
    ]
)