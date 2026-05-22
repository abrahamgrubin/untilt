// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UntiltLogic",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "UntiltLogic", targets: ["UntiltLogic"]),
    ],
    targets: [
        .target(name: "UntiltLogic"),
        .testTarget(name: "UntiltLogicTests", dependencies: ["UntiltLogic"],
                    swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]),
    ]
)
