//
//  SplashScreenView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Display the Dark Pack Logo
            Image("darkpack_logo2")
                .resizable()
                .scaledToFit()
                .frame(height: 150) // Adjust as needed
                .accessibilityLabel("Dark Pack logo")

            // Legal Notice Text
            Text(LegalNotice.paradox)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding()

            // Disclaimer
            Text(LegalNotice.darkPack)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding()

            // VoiceOver users get "Double-tap to skip" as the hint instead
            Text("Tap anywhere to continue")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Spacer()
        }
        .padding()
    }
}
