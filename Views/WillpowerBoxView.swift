//
//  WillpowerBoxView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 18/09/2024.
//

import SwiftUI

struct WillpowerBoxView: View {
    @ObservedObject var box: WillpowerBox

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                Text(box.state == .spent ? "/" : "")
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .bold()
            )
            .overlay(
                Rectangle().stroke(Color.black, lineWidth: 1)
            )
            .frame(width: 20, height: 20)
            .onTapGesture {
                box.state = box.state == .none ? .spent : .none
            }
    }
}
