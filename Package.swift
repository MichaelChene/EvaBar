// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EvaBar",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "EvaBarCore", targets: ["EvaBarCore"])
    ],
    targets: [
        .target(name: "EvaBarCore"),
        .testTarget(name: "EvaBarCoreTests", dependencies: ["EvaBarCore"])
    ]
)
