// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "openfortivpn-gui",
    defaultLocalization: "zh-Hant",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "openfortivpn-gui",
            path: "Sources/openfortivpn-gui",
            resources: [.process("Resources")]
        )
    ]
)
