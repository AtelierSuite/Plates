// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PlatesKitchen",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "PlatesKitchen", targets: ["PlatesKitchen"])],
    dependencies: [
        .package(url: "https://github.com/apple/ml-stable-diffusion.git", from: "1.1.1")
    ],
    targets: [
        .executableTarget(
            name: "PlatesKitchen",
            dependencies: [.product(name: "StableDiffusion", package: "ml-stable-diffusion")],
            resources: [.copy("Samples")]
        ),
        .testTarget(name: "PlatesKitchenTests", dependencies: ["PlatesKitchen"])
    ]
)
