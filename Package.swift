// swift-tools-version: 6.0
import PackageDescription

// Host-side tests use the same Swift models and catalogs as the Xcode app. ChroniclesCore is the code shared by every
// game's app; it mustn't depend on anything game-specific, which building it as its own target checks.
let package = Package(
    name: "RequiemCharacterSheet",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ChroniclesCore", path: "Chronicles/Core"),
        .target(
            name: "RequiemCharacterSheet", dependencies: ["ChroniclesCore"], path: "RequiemCharacterSheet",
            exclude: ["App", "Assets.xcassets", "Fonts", "Info.plist", "Preview Content",
                      "RequiemCharacterSheet.entitlements", "Views"],
            sources: ["Models", "Persistence"],
            resources: [.process("Catalogs")]
        ),
        .testTarget(name: "RequiemCharacterSheetTests", dependencies: ["RequiemCharacterSheet", "ChroniclesCore"],
                    path: "RequiemCharacterSheetTests")
    ],
    swiftLanguageModes: [.v5]
)
