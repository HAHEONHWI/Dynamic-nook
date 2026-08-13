// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "nook3h",
    defaultLocalization: "en",
    platforms: [.macOS("14.6")],
    products: [
        .executable(name: "nook3h", targets: ["NookClone"])
    ],
    targets: [
        .executableTarget(
            name: "NookClone",
            dependencies: ["MediaRemoteBridgeC", "SystemDisplayBridgeC"],
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
            dependencies: ["NookClone"],
            path: "Tests/NookCloneTests"
        )
    ]
)
