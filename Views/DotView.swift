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
    var isInteractive: Bool = true // I ended up setting this to true. This is not as clean as having a single approach to all the dots on the sheet, but it works for now
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
