// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PocketPetCore",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "PocketPetCore", targets: ["PocketPetCore"]),
    ],
    targets: [
        .target(name: "PocketPetCore"),
        .testTarget(
            name: "PocketPetCoreTests",
            dependencies: ["PocketPetCore"]
        ),
    ]
)
