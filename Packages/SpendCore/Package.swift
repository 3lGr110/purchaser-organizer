// swift-tools-version:5.9
import PackageDescription

/// SpendCore holds the platform-independent brain of the app:
/// merchant normalization, categorization and spending analytics.
/// It only depends on Foundation so it can be unit-tested with `swift test`.
let package = Package(
    name: "SpendCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SpendCore", targets: ["SpendCore"])
    ],
    targets: [
        .target(name: "SpendCore"),
        .testTarget(name: "SpendCoreTests", dependencies: ["SpendCore"])
    ]
)
