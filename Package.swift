// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Shikisha",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "Shikisha", targets: ["Shikisha"])
    ],
    targets: [
        .target(
            name: "Shikisha",
            path: "Sources/Shikisha",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "ShikishaTests",
            dependencies: ["Shikisha"],
            path: "Tests/ShikishaTests",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
