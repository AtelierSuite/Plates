// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PlatesKitchen",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "PlatesKitchen", targets: ["PlatesKitchen"])],
    targets: [
        .executableTarget(name: "PlatesKitchen"),
        .testTarget(name: "PlatesKitchenTests", dependencies: ["PlatesKitchen"])
    ]
)
