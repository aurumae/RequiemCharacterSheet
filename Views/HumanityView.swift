//
//  HumanityView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct HumanityView: View {
    @ObservedObject var character: Character

    var body: some View {
        VStack(spacing: 4) {
            ForEach(character.touchstones.sorted(by: { $0.level > $1.level })) { touchstone in
                HumanityRowView(touchstone: touchstone, humanity: $character.humanity)
            }
        }
    }
}
