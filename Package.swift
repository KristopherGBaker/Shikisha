// swift-tools-version: 6.3
import PackageDescription
import class Foundation.ProcessInfo

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
        .executableTarget(
            name: "ShikishaExamples",
            dependencies: ["Shikisha"],
            path: "Examples/ShikishaExamples"
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

// The Swift-DocC plugin is only needed when building documentation (`make docs`), so it is
// added behind an environment gate to avoid imposing it as a dependency on packages that
// depend on Shikisha. See https://github.com/swiftlang/swift-docc-plugin for details.
if ProcessInfo.processInfo.environment["SHIKISHA_BUILD_DOCS"] != nil {
    package.dependencies.append(
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0")
    )
}
