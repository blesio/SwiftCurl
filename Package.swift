// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftCurl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SwiftCurl", targets: ["SwiftCurl"])
    ],
    targets: [
        .executableTarget(
            name: "SwiftCurl",
            path: "Sources/SwiftCurl"
        )
    ]
)
