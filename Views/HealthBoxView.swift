//
//  BoxView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 17/09/2024.
//

import SwiftUI

struct HealthBoxView: View {
    @ObservedObject var box: HealthBox
    var isPenalty: Bool = false
    
    var body: some View {
        Rectangle()
            .fill(Color.clear) // Fill with clear or white color for all boxes
            .overlay(
                Text(symbolForFillType(box.damageType))
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .bold()
            )
            .overlay(
                Rectangle().stroke(
                    isPenalty ? Color(red: 88/255, green: 26/255, blue: 18/255) : Color.black,
                    lineWidth: isPenalty ? 3 : 1
                )
            )
            .frame(width: 20, height: 20)
    }
    
    func symbolForFillType(_ type: HealthBoxFillType) -> String {
        switch type {
        case .bashing:
            return "/"
        case .lethal:
            return "X"
        case .aggravated:
            return "✱"
        case .none:
            return ""
        }
    }
}
