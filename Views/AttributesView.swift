//
//  AttributesView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//


import SwiftUI

struct AttributesView: View {
    @ObservedObject var character: Character
    
    // Attribute categories
    let mentalAttributes = ["Intelligence", "Wits", "Resolve"]
    let physicalAttributes = ["Strength", "Dexterity", "Stamina"]
    let socialAttributes = ["Presence", "Manipulation", "Composure"]
    
    var body: some View {
        BackgroundView {
            VStack {
                Spacer(minLength: 20)
                Image("VtR 2nd ED Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                Spacer(minLength: 20)
                
                List {
                    // CHARACTER SECTION
                    CharacterInfoView(character: character)
                    
                    // ATTRIBUTES SECTION
                    Section(header: Text("ATTRIBUTES").font(.custom("CaslonAntique", size: 24))) {
                        // MENTAL ATTRIBUTES
                        Section(header: Text("MENTAL").font(.custom("CaslonAntique", size: 20))) {
                            ForEach(character.attributes.filter { mentalAttributes.contains($0.name) }) { attribute in
                                AttributeRowView(attribute: attribute)
                            }
                        }
                        
                        // PHYSICAL ATTRIBUTES
                        Section(header: Text("PHYSICAL").font(.custom("CaslonAntique", size: 20))) {
                            ForEach(character.attributes.filter { physicalAttributes.contains($0.name) }) { attribute in
                                AttributeRowView(attribute: attribute)
                            }
                        }
                        
                        // SOCIAL ATTRIBUTES
                        Section(header: Text("SOCIAL").font(.custom("CaslonAntique", size: 20))) {
                            ForEach(character.attributes.filter { socialAttributes.contains($0.name) }) { attribute in
                                AttributeRowView(attribute: attribute)
                            }
                        }
                    }
                    
                    // SKILLS SECTION
                    SkillsView(character: character)
                    
                    // DISCIPLINES SECTION
                    DisciplinesView(character: character)
                    
                    // MERITS SECTION
                    MeritsView(character: character)
                    
                    // ASPIRATIONS SECTION
                    AspirationsView(character: character)

                    // BANES SECTION
                    BanesView(character: character)
                    
                    // HEALTH SECTION
                    Section(header: Text("HEALTH").font(.custom("CaslonAntique", size: 24))) {
                        HealthView(character: character)
                    }
                    
                    // WILLPOWER SECTION
                    Section(header: Text("WILLPOWER").font(.custom("CaslonAntique", size: 24))) {
                        WillpowerView(character: character)
                    }
                    
                    // BLOOD POTENCY SECTION
                    Section(header: Text("BLOOD POTENCY").font(.custom("CaslonAntique", size: 24))) {
                        BloodPotencyView(character: character)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                            .contentShape(Rectangle())
                    }
                    // VITAE SECTION
                    Section(header: Text("VITAE").font(.custom("CaslonAntique", size: 24))) {
                        VitaeView(character: character)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Do nothing to disable row selection
                            }
                    }
                    
                    // HUMANITY SECTION
                    Section(header: Text("HUMANITY").font(.custom("CaslonAntique", size: 24))) {
                        HumanityView(character: character)
                    }
                    
                    // DERIVED ATTRIBUTES SECTION
                    DerivedAttributesView(character: character)
                }
                .listStyle(GroupedListStyle())
                .background(Color.clear)
            }
            .padding(.horizontal)
            .padding(.top, 40)
            .padding(.bottom, 60)
        }
    }
}
