// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "Finjinon",
    defaultLocalization: "nb",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Finjinon",
            targets: ["Finjinon"]
        ),
    ],
    dependencies: [
        .package(
            url: "git@github.schibsted.io:finn/finn-client-ios.git",
            "164.1.0"..."999.0.0"
        ),
        .package(url: "https://github.com/finn-no/FinniversKit.git", exact: "139.2.0")
    ],
    targets: [
        .target(
            name: "Finjinon",
            dependencies: [
                .product(name: "FINNClient", package: "finn-client-ios"),
                "FinniversKit"
            ],
            path: "Sources",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
