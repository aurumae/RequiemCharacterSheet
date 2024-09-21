//
//  DotView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

import SwiftUI

struct DotView: View {
    var index: Int
    var isFilled: Bool
    var isInteractive: Bool = true // leaving in the possibility of making the dots interactive by setting this to true
    var action: ((Int) -> Void)?
    
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
}
