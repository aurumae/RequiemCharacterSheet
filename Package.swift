// swift-tools-version: 6.0
import PackageDescription

// Host-side contract tests use the same Swift models and catalogs as the Xcode app.
let package = Package(
    name: "RequiemCharacterSheet",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "RequiemCharacterSheet", path: "RequiemCharacterSheet",
            exclude: ["App", "Assets.xcassets", "Fonts", "Info.plist", "Preview Content",
                      "RequiemCharacterSheet.entitlements", "Views"],
            sources: ["Models", "Persistence", "Utilities"],
            resources: [.process("Catalogs")]
        ),
        .testTarget(name: "RequiemCharacterSheetTests", dependencies: ["RequiemCharacterSheet"],
                    path: "RequiemCharacterSheetTests")
    ],
    swiftLanguageModes: [.v5]
)
