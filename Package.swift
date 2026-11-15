// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JogCon",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "JogConCore", targets: ["JogConCore"]),
        .executable(name: "JogCon", targets: ["JogCon"])
    ],
    targets: [
        .target(name: "JogConCore"),
        .executableTarget(name: "JogCon", dependencies: ["JogConCore"]),
        .testTarget(name: "JogConCoreTests", dependencies: ["JogConCore"])
    ]
)
