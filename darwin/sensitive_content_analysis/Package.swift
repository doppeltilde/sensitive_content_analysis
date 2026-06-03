// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "sensitive_content_analysis",
    platforms: [
        .iOS("13.0"),
        .macOS("12.0")
    ],
    products: [
        .library(
            name: "sensitive-content-analysis", targets: ["sensitive_content_analysis"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "sensitive_content_analysis",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            resources: [],
            linkerSettings: [
                .linkedFramework("Flutter", .when(platforms: [.iOS])),
                .linkedFramework("FlutterMacOS", .when(platforms: [.macOS])),
                .linkedFramework("SensitiveContentAnalysis", .when(platforms: [.iOS, .macOS]))
            ]
        )
    ]
)