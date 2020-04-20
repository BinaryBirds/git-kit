// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "git-kit",
    products: [
        .library(name: "GitKit", targets: ["GitKit"]),
        .library(name: "GitKitDynamic", type: .dynamic, targets: ["GitKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/binarybirds/shell-kit", from: "1.0.0"),
    ],
    targets: [
        .target(name: "GitKit", dependencies: [
            .product(name: "ShellKit", package: "shell-kit"),
        ]),
        .testTarget(name: "GitKitTests", dependencies: ["GitKit"]),
    ]
)
