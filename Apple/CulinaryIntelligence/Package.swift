// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CulinaryIntelligence",
    defaultLocalization: "en-US",
    platforms: [.iOS("27.0")],
    products: [
        .library(name: "CulinaryIntelligence", targets: ["CulinaryIntelligence"]),
    ],
    targets: [
        .target(
            name: "CulinaryIntelligence",
            resources: [.process("Resources")],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
