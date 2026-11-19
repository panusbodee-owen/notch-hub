// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NotchHub",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "NotchHubCore", targets: ["NotchHubCore"]),
        .executable(name: "NotchHub", targets: ["NotchHub"]),
        .executable(name: "NotchHubSelfTest", targets: ["NotchHubSelfTest"])
    ],
    targets: [
        .target(
            name: "NotchHubCore",
            path: "Sources/NotchHubCore"
        ),
        .executableTarget(
            name: "NotchHub",
            dependencies: ["NotchHubCore"],
            path: "Sources/NotchHub"
        ),
        .executableTarget(
            name: "NotchHubSelfTest",
            dependencies: ["NotchHubCore"],
            path: "Sources/NotchHubSelfTest"
        )
    ]
)
