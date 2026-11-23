// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Encore",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1")
    ],
    targets: [
        .executableTarget(
            name: "Encore",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Encore",
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        )
    ],
    swiftLanguageModes: [.v5]
)
