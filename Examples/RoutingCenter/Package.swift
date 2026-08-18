// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RoutingCenterExample",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "RoutingCenterExample",
            dependencies: [
                .product(name: "Pathways", package: "pathways-swift")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
