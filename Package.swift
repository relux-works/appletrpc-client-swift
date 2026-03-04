// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "javacard-rpc-client-swift",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "JavaCardRPCClient", targets: ["JavaCardRPCClient"]),
    ],
    targets: [
        .target(
            name: "JavaCardRPCClient",
            path: "Sources/JavaCardRPCClient"
        ),
    ]
)
