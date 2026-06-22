import ProjectDescription

let project = Project(
    name: "Verdigris",
    options: .options(
        automaticSchemesOptions: .enabled()
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "DEVELOPMENT_TEAM": "T9G4KUKSVP",
        ]
    ),
    targets: [
        .target(
            name: "Verdigris",
            destinations: [.iPhone],
            product: .app,
            bundleId: "com.verdigris",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "NSCameraUsageDescription": "Verdigris uses the camera to identify plants and diagnose problems.",
                "UILaunchScreen": [:],
                "UIBackgroundModes": [
                    "remote-notification",
                ],
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            entitlements: "Resources/Entitlements.plist",
            dependencies: [
                .external(name: "Dependencies"),
            ]
        ),
        .target(
            name: "VerdigrisTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "com.verdigris.tests",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "Verdigris"),
                .external(name: "SnapshotTesting"),
            ]
        ),
    ]
)
