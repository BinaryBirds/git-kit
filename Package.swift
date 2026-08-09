// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "git-kit",
    products: [
        .library(name: "GitKit", targets: ["GitKit"]),
    ],
    dependencies: [],
    targets: [
        // Vendored from BinaryBirds/shell-kit (WTFPL); the upstream repo was
        // deleted from GitHub and can no longer be resolved as a dependency.
        .target(name: "ShellKit"),
        .target(name: "GitKit", dependencies: [
            "ShellKit",
        ]),
        .testTarget(name: "GitKitTests", dependencies: ["GitKit"]),
    ]
)
