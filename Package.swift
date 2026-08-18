// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "nook3h",
    defaultLocalization: "en",
    platforms: [.macOS("14.6")],
    products: [
        .executable(name: "nook3h", targets: ["NookClone"]),
        .executable(name: "DynamicNookLicenseIssuer", targets: ["DynamicNookLicenseIssuer"]),
        .executable(name: "DynamicNookLicenseSecretExporter", targets: ["DynamicNookLicenseSecretExporter"])
    ],
    targets: [
        .executableTarget(
            name: "NookClone",
            dependencies: ["LicenseCore", "MediaRemoteBridgeC", "SystemDisplayBridgeC"],
            path: "Sources/NookClone",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("NetworkExtension"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .target(
            name: "LicenseCore",
            path: "Sources/LicenseCore"
        ),
        .executableTarget(
            name: "DynamicNookLicenseIssuer",
            dependencies: ["LicenseCore"],
            path: "Tools/DynamicNookLicenseIssuer",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "DynamicNookLicenseSecretExporter",
            dependencies: ["LicenseCore"],
            path: "Tools/DynamicNookLicenseSecretExporter",
            linkerSettings: [.linkedFramework("Security")]
        ),
        .target(
            name: "MediaRemoteBridgeC",
            path: "Sources/MediaRemoteBridgeC",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Foundation")
            ]
        ),
        .target(
            name: "SystemDisplayBridgeC",
            path: "Sources/SystemDisplayBridgeC",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "NookCloneTests",
            dependencies: ["LicenseCore", "NookClone"],
            path: "Tests/NookCloneTests"
        )
    ]
)
