// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodableRoutesExample",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "CodableRoutesExample",
            dependencies: [
                .product(name: "Pathways", package: "pathways-swift")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
