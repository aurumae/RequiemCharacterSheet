//
//  AttributeRowView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

// Only Attribute names tappable
import SwiftUI

struct AttributeRowView: View {
    @ObservedObject var attribute: Attribute
    @State private var showingPicker = false
    
    var body: some View {
        HStack {
            Button(action: {
                showingPicker = true
            }) {
                Text(attribute.name)
                    .font(.custom("CaslonAntique", size: 22))
                    .foregroundColor(.vampireRed) // Apply the custom red color here
            }
            .buttonStyle(PlainButtonStyle())
            .actionSheet(isPresented: $showingPicker) {
                ActionSheet(title: Text("Set \(attribute.name)"), message: nil, buttons: actionSheetButtons())
            }
            Spacer()
            DotsRatingView(rating: $attribute.rating, maxRating: attribute.rating > 5 ? attribute.rating : 5)
        }
        .padding(.vertical, 4)
    }
    
    func actionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        for value in 1...10 {
            buttons.append(.default(Text("\(value)")) {
                attribute.rating = value
            })
        }
        buttons.append(.cancel())
        return buttons
    }
}
