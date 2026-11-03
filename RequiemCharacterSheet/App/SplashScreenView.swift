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

            // Legal Notice Text
            Text("Portions of the materials are the copyrights and trademarks of Paradox Interactive AB, and are used with permission. All rights reserved. For more information please visit worldofdarkness.com.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding()

            // Disclaimer
            Text("This is unofficial Fan Content permitted under the Dark Pack. This app is not official World of Darkness material.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
        .padding()
    }
}
