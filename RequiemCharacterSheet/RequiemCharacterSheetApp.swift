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
                // Keep the splash screen visible for 5 seconds
                try? await Task.sleep(for: .seconds(5))

                // Fade out the splash screen over 2 seconds
                withAnimation(.easeOut(duration: 2)) {
                    splashOpacity = 0.0
                } completion: {
                    showsSplash = false
                }

                // After splash screen has faded out, fade in the main app view over 1 second
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeIn(duration: 1)) {
                    mainOpacity = 1.0
                }
            }
        }
    }
}
