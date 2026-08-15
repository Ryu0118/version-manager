// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "version-manager",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "version-manager", targets: ["version-manager"]),
        .library(name: "VersionManagerKit", targets: ["VersionManagerKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.2"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.2"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.1"),
        .package(url: "https://github.com/jpsim/Yams", from: "6.2.0"),
        .package(url: "https://github.com/tuist/FileSystem", from: "0.13.47"),
        .package(url: "https://github.com/Ryu0118/FileManagerProtocol", from: "0.1.0"),
        .package(url: "https://github.com/Ryu0118/ProcessRunning", from: "0.2.1"),
        .package(url: "https://github.com/swiftlang/swift-subprocess", "0.2.1" ..< "0.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "version-manager",
            dependencies: ["VersionManagerCLI"]
        ),
        .target(
            name: "VersionManagerCLI",
            dependencies: [
                "VersionManagerKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ProcessRunning", package: "ProcessRunning"),
            ]
        ),
        .target(
            name: "VersionManagerKit",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
                .product(name: "Glob", package: "FileSystem"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Rainbow", package: "Rainbow"),
                .product(name: "FileManagerProtocol", package: "FileManagerProtocol"),
                .product(name: "ProcessRunning", package: "ProcessRunning"),
                .product(name: "Subprocess", package: "swift-subprocess"),
            ]
        ),
        .testTarget(
            name: "VersionManagerKitTests",
            dependencies: [
                "VersionManagerKit",
                .product(name: "Yams", package: "Yams"),
                .product(name: "FileManagerProtocol", package: "FileManagerProtocol"),
                .product(name: "ProcessRunning", package: "ProcessRunning"),
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
            exclude: ["Fixtures"]
        ),
        .testTarget(
            name: "VersionManagerCLITests",
            dependencies: ["VersionManagerCLI"]
        ),
    ]
)
