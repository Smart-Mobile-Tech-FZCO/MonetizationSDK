// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PaymentSDK",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "PaymentSDK", targets: ["PaymentSDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/PhoneNumberKit/PhoneNumberKit", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "PaymentSDK",
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
            name: "PaymentSDKTests",
            dependencies: ["PaymentSDK"],
            resources: [
                .copy("Fixtures"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
