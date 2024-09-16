//
//  AspirationRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct AspirationRowView: View {
    @ObservedObject var aspiration: Aspiration

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $aspiration.text)
                .frame(minHeight: 40, maxHeight: 100) // Adjust minHeight and maxHeight as needed
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .font(.system(size: 16))
        }
        .padding(.vertical, 4)
    }
}