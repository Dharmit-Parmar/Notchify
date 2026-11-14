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
        .target(
            name: "LocalShare",
            dependencies: [],
            path: "Sources/Modules/LocalShare",
            exclude: [
                "LocalShareModule.swift",
                "LocalShareExpandedView.swift",
                "LocalShareSettingsView.swift"
            ]
        ),
        .executableTarget(
            name: "NotchApp",
            dependencies: ["LocalShare"],
            path: "Sources",
            exclude: [
                "Modules/LocalShare/LocalShareProtocol.swift",
                "Modules/LocalShare/LocalShareIdentity.swift",
                "Modules/LocalShare/LocalShareSecurity.swift",
                "Modules/LocalShare/LocalShareFileManager.swift",
                "Modules/LocalShare/LocalShareSession.swift",
                "Modules/LocalShare/LocalShareServer.swift",
                "Modules/LocalShare/LocalShareDiscovery.swift",
                "Modules/LocalShare/LocalShareClient.swift",
                "Modules/LocalShare/LocalShareSettings.swift",
                "Modules/LocalShare/LocalShareModuleState.swift"
            ]
        ),
        .executableTarget(
            name: "NotchTests",
            dependencies: ["LocalShare"],
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
