// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "LucidCodeGen",
    products: [
        .executable(name: "lucid", targets: ["LucidCommand"]),
        .library(name: "LucidCodeGenExtension", targets: ["LucidCodeGenExtension"])
    ],
    dependencies: [
        .package(url: "https://github.com/kylef/Commander.git", from: "0.8.0"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "0.9.2"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0"),
        .package(url: "https://github.com/scribd/Meta.git", .branch("master")),
        .package(url: "https://github.com/jpsim/Yams.git", from: "2.0.0")
    ],
    targets: [
        .target(name: "LucidCodeGenCore", dependencies: ["PathKit", "Meta", "ShellOut"]),
        .target(name: "LucidCodeGen", dependencies: ["LucidCodeGenCore", "PathKit", "Meta"]),
        .testTarget(name: "LucidCodeGenTests", dependencies: ["LucidCodeGenCore", "LucidCodeGen"]),
        .target(name: "LucidCommand", dependencies: ["Commander", "ShellOut", "Yams", "LucidCodeGenCore", "LucidCodeGen"]),
        .target(name: "LucidCodeGenExtension", dependencies: ["Commander", "LucidCodeGenCore"])
    ]
)
