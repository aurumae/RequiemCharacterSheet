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
                    path: "RequiemCharacterSheetTests"),
        // Forsaken's models and catalogs, as its Xcode app builds them. Its catalog also reads Requiem's
        // cofd-core.json from the checkout (see ForsakenCatalog.swift).
        .target(
            name: "ForsakenCharacterSheet", dependencies: ["ChroniclesCore"], path: "ForsakenCharacterSheet",
            exclude: ["App", "Assets.xcassets", "Fonts", "Info.plist", "Views"],
            sources: ["Models"],
            resources: [.process("Catalogs")]
        ),
        // SheetSectionTests needs the app's views and artwork, so it runs in Xcode only.
        .testTarget(name: "ForsakenCharacterSheetTests", dependencies: ["ForsakenCharacterSheet", "ChroniclesCore"],
                    path: "ForsakenCharacterSheetTests", exclude: ["SheetSectionTests.swift"],
                    resources: [.process("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
