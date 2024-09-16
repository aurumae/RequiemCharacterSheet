//
//  EditableDotRatingView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//

import SwiftUI

struct EditableDotsRatingView: View {
    @Binding var rating: Int
    var maxRating: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { number in
                Image(systemName: "circle.fill")
                    .resizable()
                    .overlay(Circle().stroke(Color.black, lineWidth: 1) )
                    .frame(width: 20, height: 20)
                    .foregroundColor(number <= rating ? .vampireRed : .clear)
                    .onTapGesture {
                        rating = number
                    }
            }
        }
    }
}

/*
 var body: some View {
     Circle()
         .fill(isFilled ? Color.vampireRed : Color.clear)
         .overlay(Circle().stroke(Color.black, lineWidth: 1))
         .frame(width: 20, height: 20)
         .onTapGesture {
             if isInteractive, let action = action {
                 action(index)
             }
         }
 }
 */
