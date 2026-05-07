// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "JayPetApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "JayPetApp", targets: ["JayPetApp"])
    ],
    targets: [
        .executableTarget(
            name: "JayPetApp",
            path: "Sources/JayPetApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
