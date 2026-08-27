// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "git-kit",
    // swift-subprocess declares a floor of macOS 13.
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GitKit", targets: ["GitKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.4.0"),
    ],
    targets: [
        .target(name: "GitKit", dependencies: [
            .product(name: "Subprocess", package: "swift-subprocess"),
        ]),
        .testTarget(name: "GitKitTests", dependencies: ["GitKit"]),
    ]
)
