// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TillReceipt",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TillReceipt", targets: ["TillReceipt"])
    ],
    targets: [
        .target(name: "TillReceipt"),
        .testTarget(
            name: "TillReceiptTests",
            dependencies: ["TillReceipt"],
            resources: [.process("Fixtures")]
        ),
    ]
)
