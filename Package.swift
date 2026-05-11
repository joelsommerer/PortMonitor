// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PortMonitor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PortMonitor",
            path: "Sources/PortMonitor"
        )
    ]
)
