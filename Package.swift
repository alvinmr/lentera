// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lentera",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Lentera",
            path: "Sources/Lentera",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "LenteraTests", dependencies: ["Lentera"])
    ]
)
