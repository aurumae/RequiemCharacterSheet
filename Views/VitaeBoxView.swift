//
//  VitaeBoxView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct VitaeBoxView: View {
    @ObservedObject var box: VitaeBox

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                Circle()
                    .fill(Color.vampireRed)
                    .frame(width: 15, height: 15)
                    .opacity(box.isFilled ? 1 : 0)
                    .animation(.default, value: box.isFilled)
            )
            .overlay(
                Rectangle().stroke(Color.black, lineWidth: 1)
            )
            .frame(width: 34, height: 34)
            .onTapGesture {
                box.isFilled.toggle()
            }
    }
}
