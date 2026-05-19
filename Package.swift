// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "smooth-scroll",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SmoothScrollCore", targets: ["SmoothScrollCore"]),
        .executable(name: "SmoothScroll", targets: ["SmoothScroll"])
    ],
    targets: [
        .target(name: "SmoothScrollCore"),
        .executableTarget(
            name: "SmoothScroll",
            dependencies: ["SmoothScrollCore"]
        )
    ]
)
