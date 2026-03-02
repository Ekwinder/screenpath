// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenPath",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ScreenPath", targets: ["ScreenPath"])
    ],
    targets: [
        .executableTarget(
            name: "ScreenPath",
            path: "Sources/ScreenPath"
        )
    ]
)
