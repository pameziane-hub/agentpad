// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "agentpad",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "AgentpadCore"),
        .executableTarget(name: "agentpad", dependencies: ["AgentpadCore"]),
        .testTarget(name: "AgentpadCoreTests", dependencies: ["AgentpadCore"]),
    ]
)
