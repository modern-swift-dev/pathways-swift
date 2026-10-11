// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Pathways",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "Pathways", targets: ["Pathways"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0")
    ],
    targets: [
        .target(name: "Pathways"),
        .testTarget(name: "PathwaysTests", dependencies: ["Pathways"])
    ],
    swiftLanguageModes: [.v6]
)
