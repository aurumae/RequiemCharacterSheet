//
//  SplashContainer.swift
//  Chronicles
//

import SwiftUI

/// Shows the Dark Pack splash screen for a few seconds, or until it's tapped, then fades in the app.
struct SplashContainer<Content: View>: View {
    @ViewBuilder let content: Content

    @State private var splashOpacity = 1.0
    @State private var showsSplash = true
    @State private var isDismissingSplash = false
    @State private var mainOpacity = 0.0

    var body: some View {
        ZStack {
            content
                .opacity(mainOpacity)
                // Keep VoiceOver on the splash screen until the app fades in
                .accessibilityHidden(mainOpacity == 0)
                // Nor can a tap that skips the splash screen reach the list behind it
                .allowsHitTesting(!showsSplash)

            // Removed once it has faded out, so VoiceOver doesn't read it
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
            // Five seconds in all: the splash screen stays for 4, fades out, then the app fades in
            try? await Task.sleep(for: .seconds(4))
            await dismissSplash(fadeOut: 0.5, pause: 0.1, fadeIn: 0.4)
        }
    }

    /// Fades out the splash screen, waits `pause` seconds, then fades in the app.
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
