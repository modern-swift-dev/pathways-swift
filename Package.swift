// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Pathways",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "Pathways", targets: ["Pathways"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "Pathways"),
        .testTarget(name: "PathwaysTests", dependencies: ["Pathways"])
    ],
    swiftLanguageModes: [.v6]
)
