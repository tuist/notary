// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "notary",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto", from: "3.10.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.25.0"),
    ],
    targets: [
        .executableTarget(
            name: "notary",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "NotaryCore"
            ]
        ),
        .target(
            name: "NotaryCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
        .testTarget(
            name: "NotaryCoreTests",
            dependencies: ["NotaryCore"]
        )
    ]
)
