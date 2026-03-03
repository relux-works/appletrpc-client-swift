// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "appletrpc-client-swift",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "AppletRPCClient", targets: ["AppletRPCClient"]),
    ],
    targets: [
        .target(
            name: "AppletRPCClient",
            path: "Sources/AppletRPCClient"
        ),
    ]
)
