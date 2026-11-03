//
//  CharacterSheetView.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//


import SwiftUI

struct CharacterSheetView: View {
    let character: Character
    let store: CharacterStore

    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSavedConfirmation = false
    @State private var saveErrorMessage: String?

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
                        // MENTAL, PHYSICAL and SOCIAL ATTRIBUTES
                        ForEach(TraitCategory.allCases, id: \.self) { category in
                            Section(header: Text(category.title).font(.custom("CaslonAntique", size: 20))) {
                                ForEach(character.attributes.filter { $0.kind.category == category }) { attribute in
                                    AttributeRowView(character: character, attribute: attribute)
                                }
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
            // Content sits inside the safe area (below the navigation bar); this keeps it clear of the bottom border
            .padding(.bottom, 26)
        }
        // Let the parchment border show behind the navigation bar
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(showsSavedConfirmation ? "Saved" : "Save") {
                    save(showingConfirmation: true)
                }
                .disabled(showsSavedConfirmation)
            }
        }
        // Keep changes if the app is backgrounded or closed while the sheet is open
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                save(showingConfirmation: false)
            }
        }
        .alert(
            "Couldn't Save Character",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private func save(showingConfirmation: Bool) {
        do {
            try store.save(character)
        } catch {
            saveErrorMessage = error.localizedDescription
            return
        }
        guard showingConfirmation else { return }
        showsSavedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showsSavedConfirmation = false
        }
    }
}
