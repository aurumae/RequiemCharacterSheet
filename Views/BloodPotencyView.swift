//
//  BloodPotencyView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 17/09/2024.
//


import SwiftUI

struct BloodPotencyView: View {
    @ObservedObject var character: Character

    var body: some View {
        VStack(alignment: .leading) {
            //Text("Blood Potency")
            //    .font(.custom("CaslonAntique", size: 18))
            HStack {
                DotsRatingView(rating: $character.bloodPotency, maxRating: 10, dotsPerRow: 10)
                Spacer()
                HStack(spacing: 16) {
                    Button(action: {
                        if character.bloodPotency < 10 {
                            character.bloodPotency += 1
                            print("Blood Potency increased to \(character.bloodPotency)")
                        }
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(character.bloodPotency >= 10)
                    .accessibility(label: Text("Increase Blood Potency"))

                    Button(action: {
                        if character.bloodPotency > 0 {
                            character.bloodPotency -= 1
                            print("Blood Potency decreased to \(character.bloodPotency)")
                        }
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.title2)
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(character.bloodPotency <= 0)
                    .accessibility(label: Text("Decrease Blood Potency"))
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Limits tap area to the content
    }
}
