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

/* Names and dots tappable
import SwiftUI

struct AttributeRowView: View {
    @ObservedObject var attribute: Attribute
    @State private var showingPicker = false

    var body: some View {
        HStack {
            // Attribute Name Button
            Button(action: {
                showingPicker = true
            }) {
                Text(attribute.name)
                    .font(.custom("CaslonAntique", size: 22))
                    .foregroundColor(.vampireRed)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Dots Rating Button
            Button(action: {
                showingPicker = true
            }) {
                DotsRatingView(rating: $attribute.rating, maxRating: attribute.rating > 5 ? attribute.rating : 5)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        // Attach the ActionSheet to the entire HStack
        .actionSheet(isPresented: $showingPicker) {
            ActionSheet(title: Text("Set \(attribute.name)"), message: nil, buttons: actionSheetButtons())
        }
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
*/

/* Whole row tappable
import SwiftUI

struct AttributeRowView: View {
    @ObservedObject var attribute: Attribute
    @State private var showingPicker = false

    var body: some View {
        HStack {
            Text(attribute.name)
                .font(.custom("CaslonAntique", size: 22))
                .foregroundColor(.vampireRed)

            Spacer()

            DotsRatingView(rating: $attribute.rating, maxRating: attribute.rating > 5 ? attribute.rating : 5)
        }
        .padding(.vertical, 4)
        // Make the entire row tappable
        .contentShape(Rectangle()) // Ensure the HStack's entire area is tappable
        .onTapGesture {
            showingPicker = true
        }
        .actionSheet(isPresented: $showingPicker) {
            ActionSheet(title: Text("Set \(attribute.name)"), message: nil, buttons: actionSheetButtons())
        }
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
*/
