//
//  RequiemCharacterSheetApp.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

import SwiftUI
import UIKit

@main
struct RequiemCharacterSheetApp: App {
    @State private var splashOpacity = 1.0
    @State private var mainOpacity = 0.0
    @StateObject var character = Character.load()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main App View
                AttributesView(character: character)
                    .opacity(mainOpacity)
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        character.save()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                        character.save()
                    }

                // Splash Screen View
                SplashScreenView()
                    .opacity(splashOpacity)
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
