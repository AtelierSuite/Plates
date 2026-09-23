// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlatesKitchen",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "PlatesKitchen", targets: ["PlatesKitchen"])],
    targets: [
        .executableTarget(name: "PlatesKitchen"),
        .testTarget(name: "PlatesKitchenTests", dependencies: ["PlatesKitchen"])
    ]
)
