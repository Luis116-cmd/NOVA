// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NOVA",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NOVA", targets: ["NOVA"])
    ],
    targets: [
        .executableTarget(
            name: "NOVA",
            path: "Sources/NOVA",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech"),
                .linkedFramework("Security")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)