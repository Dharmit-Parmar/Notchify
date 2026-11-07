// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotchApp", targets: ["NotchApp"]),
        .executable(name: "NotchTests", targets: ["NotchTests"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NotchApp",
            dependencies: [],
            path: "Sources"
        ),
        .executableTarget(
            name: "NotchTests",
            dependencies: [],
            path: "Tests",
            exclude: [
                "CompanionFrameStripGenerator.swift",
                "CompanionFrameStripStubs.swift",
                "CompanionProductionPoseChecks.swift",
                "KinematicAcceptanceTests.swift"
            ],
            sources: ["VerificationTests.swift"]
        )
    ]
)
