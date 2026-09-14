// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeskOrbit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DeskOrbit", targets: ["DeskOrbit"])
    ],
    targets: [
        .executableTarget(
            name: "DeskOrbit",
            dependencies: [],
            path: "Sources/DevicesControl",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("IOKit"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("DiskArbitration"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
