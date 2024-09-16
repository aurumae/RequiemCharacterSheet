//
//  BaneRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct BaneRowView: View {
    @ObservedObject var bane: Bane

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $bane.text)
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