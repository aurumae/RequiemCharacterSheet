//
//  RequiemCharacterSheetApp.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

import SwiftUI

@main
struct RequiemCharacterSheetApp: App {
    @State private var splashOpacity = 1.0
    @State private var showsSplash = true
    @State private var isDismissingSplash = false
    @State private var mainOpacity = 0.0
    @State private var store = CharacterStore()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main App View
                CharacterListView(store: store)
                    .opacity(mainOpacity)
                    // Keep VoiceOver on the splash screen until the list fades in
                    .accessibilityHidden(mainOpacity == 0)

                // Splash Screen View, removed once it has faded out so VoiceOver doesn't read it
                if showsSplash {
                    SplashScreenView()
                        .opacity(splashOpacity)
                        // Tapping anywhere skips the wait
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task { await dismissSplash(fadeOut: 0.4, pause: 0.2, fadeIn: 0.4) }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Double-tap to skip")
                        .accessibilityAction(named: "Skip") {
                            Task { await dismissSplash(fadeOut: 0.4, pause: 0.2, fadeIn: 0.4) }
                        }
                }
            }
            .task {
                // Earlier versions saved a single character in UserDefaults; move it into the store.
                // If it can't be read it's left where it is, so nothing is lost.
                do {
                    try store.migrateLegacySaveIfNeeded()
                } catch {
                    print("Couldn't move the previously saved character: \(error)")
                }
            }
            .task {
                // Keep the splash screen visible for 5 seconds, then fade it out over 2 seconds
                // and fade in the main app view over 1 second
                try? await Task.sleep(for: .seconds(5))
                await dismissSplash(fadeOut: 2, pause: 2, fadeIn: 1)
            }
        }
    }

    /// Fades out the splash screen, waits `pause` seconds, then fades in the main view.
    /// Only the first call has any effect, so a tap and the timer can't both run it.
    private func dismissSplash(fadeOut: Double, pause: Double, fadeIn: Double) async {
        guard !isDismissingSplash else { return }
        isDismissingSplash = true

        withAnimation(.easeOut(duration: fadeOut)) {
            splashOpacity = 0.0
        } completion: {
            showsSplash = false
        }

        try? await Task.sleep(for: .seconds(pause))
        withAnimation(.easeIn(duration: fadeIn)) {
            mainOpacity = 1.0
        }
    }
}
