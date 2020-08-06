// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "LucidCustomExtensions",
    products: [
      .executable(name: "lucid-extensions", targets: ["LucidCommandCustomExtensions"])
    ],
    dependencies: [
        .package(url: "https://github.com/kylef/Commander.git", from: "0.8.0"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "0.9.2"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0"),
        .package(url: "https://github.com/scribd/Meta.git", .branch("master")),
        .package(url: "https://github.com/jpsim/Yams.git", from: "2.0.0")
    ],
    targets: [
        .target(name: "LucidCodeGenCore", dependencies: ["PathKit", "Meta"]),
        .target(name: "LucidCodeGenCustomExtensions", dependencies: ["LucidCodeGenCore", "PathKit", "Meta"]),
        .target(name: "LucidCommandCustomExtensions", dependencies: ["Commander", "ShellOut", "Yams", "LucidCodeGenCore", "LucidCodeGenCustomExtensions"])
    ]
)
