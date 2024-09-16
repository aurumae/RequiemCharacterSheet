//
//  DerivedAttributesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//


import SwiftUI

struct DerivedAttributesView: View {
    @ObservedObject var character: Character
    
    var body: some View {
        Section(header: Text("ADVANTAGES").font(.custom("CaslonAntique", size: 24))) {
            HStack {
                Text("Size:")
                    .vampireFont()
                Spacer()
                Text("\(character.size)")
                    .vampireFont()
            }
            .padding(.vertical, 4)
            
            HStack {
                Text("Speed:")
                    .vampireFont()
                Spacer()
                Text("\(character.speed)")
                    .vampireFont()
            }
            .padding(.vertical, 4)
            
            HStack {
                Text("Defense:")
                    .vampireFont()
                Spacer()
                Text("\(character.defense)")
                    .vampireFont()
            }
            .padding(.vertical, 4)
            
            HStack {
                Text("Armor:")
                    .vampireFont()
                Spacer()
                HStack(spacing: 16) {
                    Button(action: {
                        if character.armor > 0 {
                            character.armor -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.title2)
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Text("\(character.armor)")
                        .vampireFont()
                        .frame(minWidth: 30)
                    
                    Button(action: {
                        if character.armor < 32 {
                            character.armor += 1
                        }
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            
            HStack {
                Text("Initiative Mod:")
                    .vampireFont()
                Spacer()
                Text("\(character.initiativeMod)")
                    .vampireFont()
            }
            .padding(.vertical, 4)
            
            // New Beats Line
            HStack {
                Text("Beats:")
                    .vampireFont()
                Spacer()
                HStack(spacing: 16) {
                    Button(action: {
                        character.decrementBeats()
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.title2)
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Text("\(character.beats)")
                        .vampireFont()
                        .frame(minWidth: 30)
                    
                    Button(action: {
                        character.incrementBeats()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.vertical, 4)
            
            // New Experiences Line
            HStack {
                Text("Experiences:")
                    .vampireFont()
                Spacer()
                HStack(spacing: 16) {
                    Button(action: {
                        character.decrementExperiences()
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.title2)
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(character.beats <= 0)
                    
                    Text("\(character.experiences)")
                        .vampireFont()
                        .frame(minWidth: 30)
                    
                    Button(action: {
                        character.incrementExperiences()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.vampireRed)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(character.experiences <= 0)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
