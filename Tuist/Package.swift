// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "Dependencies": .framework,
        "SnapshotTesting": .framework,
    ]
)
#endif

let package = Package(
    name: "VerdigrisDependencies",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.0"),
    ]
)
