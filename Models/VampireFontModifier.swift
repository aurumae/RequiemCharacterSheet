//
//  VampireFontModifier.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

// A nice struct to apply the font, size, and color all at once
struct VampireFontModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("CaslonAntique", size: 22))
            .foregroundColor(.vampireRed)
    }
}

extension View {
    func vampireFont() -> some View {
        self.modifier(VampireFontModifier())
    }
}

extension Color {
    static let vampireRed = Color(red: 88/255, green: 26/255, blue: 18/255)
}
