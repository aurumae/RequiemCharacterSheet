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
    /// Shown for a few seconds when Experiences first fall below zero.
    @State private var showsNegativeExperienceNotice = false
    /// During guided creation, asks which favoured Attribute takes the clan's dot.
    @State private var choosingFavoredAttribute = false

    var body: some View {
        BackgroundView {
            VStack {
                Spacer(minLength: 20)
                LogoHeader()
                Spacer(minLength: 20)
                
                List {
                    // GUIDED CREATION CHECKLIST
                    if character.isInCreation {
                        CreationPanelView(character: character) {
                            choosingFavoredAttribute = true
                        }
                    }

                    // CHARACTER SECTION
                    CharacterInfoView(character: character)
                    
                    // ATTRIBUTES SECTION
                    Section(header: Text("ATTRIBUTES").themedText(.sectionHeader)) {
                        // MENTAL, PHYSICAL and SOCIAL ATTRIBUTES
                        ForEach(TraitCategory.allCases, id: \.self) { category in
                            Section(header: CategoryHeader(title: category.name, character: character, category: category, skills: false)) {
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

                    // DEVOTIONS, RITUALS and COILS SECTIONS
                    DevotionsView(character: character)
                    if character.showsRituals {
                        RitualsView(character: character)
                    }
                    if character.showsCoils {
                        CoilsView(character: character)
                    }
                    
                    // MERITS SECTION
                    MeritsView(character: character)
                    
                    // ASPIRATIONS SECTION
                    AspirationsView(character: character)

                    // BANES SECTION
                    BanesView(character: character)
                    
                    // HEALTH SECTION
                    Section(header: Text("HEALTH").themedText(.sectionHeader)) {
                        HealthView(character: character)
                    }
                    
                    // WILLPOWER SECTION
                    Section(header: Text("WILLPOWER").themedText(.sectionHeader)) {
                        WillpowerView(character: character)
                    }
                    
                    // BLOOD POTENCY SECTION
                    Section(header: Text("BLOOD POTENCY").themedText(.sectionHeader)) {
                        BloodPotencyView(character: character)
                    }
                    // VITAE SECTION
                    Section(header: Text("VITAE").themedText(.sectionHeader)) {
                        VitaeView(character: character)
                    }
                    
                    // HUMANITY SECTION
                    Section(header: Text("HUMANITY").themedText(.sectionHeader)) {
                        HumanityView(character: character)
                    }
                    
                    // DERIVED ATTRIBUTES SECTION
                    DerivedAttributesView(character: character)

                    // EXPERIENCE SECTION
                    ExperienceView(character: character)
                }
                .listStyle(.grouped)
                .background(Color.clear)
                // Scrolling ends text editing
                .scrollDismissesKeyboard(.immediately)
            }
            .padding(.horizontal)
            // Content sits inside the safe area (below the navigation bar); this keeps it clear of the bottom border
            .padding(.bottom, 26)
        }
        // Choosing a clan during guided creation asks where its free Attribute dot goes
        .onChange(of: character.clanSource) {
            if character.needsFavoredAttribute {
                choosingFavoredAttribute = true
            }
        }
        .confirmationDialog(
            "\(character.clan) Favoured Attribute",
            isPresented: $choosingFavoredAttribute,
            titleVisibility: .visible
        ) {
            ForEach(character.clanEntry?.favoredAttributes ?? [], id: \.self) { kind in
                Button(kind.name) { character.chooseFavoredAttribute(kind) }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("The clan gives one free dot to one of these. It doesn't count against your 5, 4 and 3 Attribute dots.")
        }
        // Log every change to a trait, and charge for it in XP Mode
        .background(TraitChangeRecorder(character: character, onExperiencesBelowZero: showNegativeExperienceNotice))
        // A brief notice, not a banner: a character may stay below zero for many sessions
        .overlay(alignment: .bottom) {
            if showsNegativeExperienceNotice {
                NegativeExperienceNotice(available: character.experiencesAvailable)
                    // Clear of the page border's ornament
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { showsNegativeExperienceNotice = false }
            }
        }

        // Let the parchment border show behind the navigation bar
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // Starting dots are free; XP Mode starts when creation is finished
            if !character.isInCreation {
                ToolbarItem(placement: .topBarTrailing) {
                    XPModeBadge(character: character)
                }
            }
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

    private func showNegativeExperienceNotice(available: Int) {
        withAnimation { showsNegativeExperienceNotice = true }
        AccessibilityNotification.Announcement("Experiences are now below zero, \(available)").post()
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { showsNegativeExperienceNotice = false }
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

/// Watches the character's traits and records each change in their log, and notices Experiences
/// falling below zero. It's a separate view so that watching these doesn't make the whole sheet redraw.
private struct TraitChangeRecorder: View {
    let character: Character
    let onExperiencesBelowZero: (Int) -> Void

    var body: some View {
        Color.clear
            .onChange(of: character.traitSnapshot) { old, _ in
                character.recordChanges(since: old)
            }
            .onChange(of: character.experiencesAvailable) { old, new in
                if old >= 0, new < 0 {
                    onExperiencesBelowZero(new)
                }
            }
    }
}
