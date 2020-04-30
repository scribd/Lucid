// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "LucidCodeGen",
    products: [
      .executable(name: "lucid", targets: ["LucidCommand"])
    ],
    dependencies: [
        .package(url: "https://github.com/kylef/Commander.git", from: "0.8.0"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "0.9.2"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0"),
        .package(url: "https://github.com/scribd/Meta.git", .branch("master")),
        .package(url: "https://github.com/jpsim/Yams.git", from: "2.0.0")
    ],
    targets: [
        .target(name: "LucidCodeGen", dependencies: ["PathKit", "Meta"]),
        .testTarget(name: "LucidCodeGenTests", dependencies: ["LucidCodeGen"]),
        .target(name: "LucidCommand", dependencies: ["Commander", "PathKit", "ShellOut", "Yams", "LucidCodeGen"])
    ]
)
