// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MonetizationSDK",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "MonetizationSDK", targets: ["MonetizationSDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/PhoneNumberKit/PhoneNumberKit", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "MonetizationSDK",
            dependencies: [
                .product(name: "PhoneNumberKit", package: "PhoneNumberKit"),
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "MonetizationSDKTests",
            dependencies: ["MonetizationSDK"],
            resources: [
                .copy("Fixtures"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
