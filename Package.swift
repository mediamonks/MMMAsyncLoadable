// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MMMAsyncLoadable",
    platforms: [
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
		.library(
			name: "MMMAsyncLoadable",
			targets: ["MMMAsyncLoadable"]
		)
    ],
    dependencies: [
        .package(name: "MMMLoadable", url: "https://github.com/mediamonks/MMMLoadable", .upToNextMajor(from: "1.7.0")),
        .package(name: "MMMCommonCore", url: "https://github.com/mediamonks/MMMCommonCore", .upToNextMajor(from: "1.8.2"))
    ],
    targets: [
        .target(
			name: "MMMAsyncLoadable",
			dependencies: ["MMMLoadable", "MMMCommonCore"]
		),
        .testTarget(
            name: "MMMAsyncLoadableTests",
            dependencies: ["MMMAsyncLoadable"]
		)
    ]
)
