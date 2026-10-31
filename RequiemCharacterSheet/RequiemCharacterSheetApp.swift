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
    @State private var mainOpacity = 0.0
    @State private var store = CharacterStore()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main App View
                CharacterListView(store: store)
                    .opacity(mainOpacity)

                // Splash Screen View
                SplashScreenView()
                    .opacity(splashOpacity)
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
            .onAppear {
                // Keep the splash screen visible for 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    // Fade out the splash screen over 2 seconds
                    withAnimation(.easeOut(duration: 2)) {
                        splashOpacity = 0.0
                    }

                    // After splash screen has faded out, fade in the main app view over 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeIn(duration: 1)) {
                            mainOpacity = 1.0
                        }
                    }
                }
            }
        }
    }
}
