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
    /// The Specialty being added or edited, shown here rather than in its row; see `EditSpecialtyAction`.
    @State private var specialtyEdit: SpecialtyEdit?
    @State private var specialtyDraft = ""
    /// Pickers and details opened from rows in the list, presented here; see `PresentSheetAction`.
    @State private var hostedSheet: HostedSheet?
    @State private var lastHostedSheet: HostedSheet?
    /// The section being read, shown in the pill, and whether its list of sections is open.
    @State private var currentSection: SheetSection? = .character
    @State private var showingSectionMenu = false
    @State private var sectionTracker = SheetSectionTracker()
    /// A section chosen in the pill's list, scrolled to by the list.
    @State private var sectionToShow: SheetSection?
    /// The pill keeps a section jumped to until the player scrolls, even if the sheet can't scroll far enough
    /// to bring its heading to the top, e.g. a short section at the end.
    @State private var jumpedSection: SheetSection?

    var body: some View {
        BackgroundView {
            VStack {
                Spacer(minLength: 20)
                LogoHeader()
                Spacer(minLength: 20)
                
                ScrollViewReader { proxy in
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
                        SheetSectionBlock(.attributes) {
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
                        SheetSectionBlock(.health) {
                            HealthView(character: character)
                        }
                    
                        // WILLPOWER SECTION
                        SheetSectionBlock(.willpower) {
                            WillpowerView(character: character)
                        }
                    
                        // BLOOD POTENCY SECTION
                        SheetSectionBlock(.bloodPotency) {
                            BloodPotencyView(character: character)
                        }
                        // VITAE SECTION
                        SheetSectionBlock(.vitae) {
                            VitaeView(character: character)
                        }
                    
                        // HUMANITY SECTION
                        SheetSectionBlock(.humanity) {
                            HumanityView(character: character)
                        }
                    
                        // DERIVED ATTRIBUTES SECTION
                        DerivedAttributesView(character: character)

                        // EXPERIENCE SECTION
                        ExperienceView(character: character)

                        // CONDITIONS SECTION, last so swiping through its cards doesn't interrupt scrolling
                        ConditionsView(character: character)
                    }
                    .listStyle(.grouped)
                    // Headings are rows (see SheetSectionBlock); this keeps the gap above them as it was for headers
                    .listSectionSpacing(15)
                    .background(Color.clear)
                    // Scrolling ends text editing
                    .scrollDismissesKeyboard(.immediately)
                    .pageBorderEdge()
                    // A field opening for editing is scrolled clear of the keyboard
                    // Rows can be shorter than this iOS's tall default, so Humanity's Touchstone rows stay compact.
                    // Other rows are taller than this anyway.
                    .environment(\.defaultMinListRowHeight, 36)
                    .environment(\.revealEditingField, RevealEditingFieldAction { row in
                        withAnimation {
                            proxy.scrollTo(row.id, anchor: UnitPoint(x: 0.5, y: row.anchor))
                        }
                    })
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                        sectionTracker.listFrame = frame
                    }
                    .onScrollPhaseChange { _, phase in
                        if phase == .interacting {
                            jumpedSection = nil
                        }
                    }
                    .environment(\.reportSectionHeading, ReportSectionHeadingAction { section, top in
                        sectionTracker.update(section, top: top)
                        guard jumpedSection == nil else { return }
                        if let current = sectionTracker.currentSection(in: character.sheetSections), current != currentSection {
                            currentSection = current
                        }
                    })
                    .onChange(of: sectionToShow) { _, section in
                        guard let section else { return }
                        sectionToShow = nil
                        withAnimation {
                            proxy.scrollTo(section, anchor: .top)
                        }
                    }
                    .environment(\.presentSheet, PresentSheetAction { sheet in
                        lastHostedSheet = sheet
                        hostedSheet = sheet
                    })
                    .environment(\.editSpecialty, EditSpecialtyAction { edit in
                        specialtyDraft = edit.initialText
                        specialtyEdit = edit
                    })
                }
            }
            .padding(.horizontal)
            // Content sits inside the safe area (below the navigation bar); this keeps it clear of the bottom border
            .padding(.bottom, 26)
        }
        .overlay {
            if showingSectionMenu {
                SectionMenu(sections: character.sheetSections, current: currentSection) { section in
                    showingSectionMenu = false
                    currentSection = section
                    jumpedSection = section
                    sectionToShow = section
                } close: {
                    withAnimation(.snappy(duration: 0.2)) { showingSectionMenu = false }
                }
            }
        }
        .modifier(SpecialtyPrompt(character: character, edit: $specialtyEdit, draft: $specialtyDraft))
        .sheetHost($hostedSheet, lastPresented: $lastHostedSheet)
        // Choosing a clan, or a bloodline with its own favoured Attributes, during guided creation asks where the free
        // Attribute dot goes
        .onChange(of: [character.clanSource, character.bloodlineSource]) {
            // The clan is usually chosen in a picker; ask once it has closed, as an alert can't show over it
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                if character.needsFavoredAttribute {
                    choosingFavoredAttribute = true
                }
            }
        }
        // An alert, not a menu: it always sits in the middle of the screen and always shows "Not Now"
        .alert(
            "\(character.creationFavoredAttributeGiver ?? character.clan) Favoured Attribute",
            isPresented: $choosingFavoredAttribute
        ) {
            ForEach(character.creationFavoredAttributes, id: \.self) { kind in
                Button(kind.name) { character.chooseFavoredAttribute(kind) }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("The \(character.creationFavoredAttributeGiver == character.bloodlineEntry?.name ? "bloodline" : "clan") gives one free dot to one of these. It doesn't count against your 5, 4 and 3 Attribute dots.")
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
            // Jumps between the sheet's sections
            ToolbarItem(placement: .topBarLeading) {
                SectionPill(current: currentSection, isOpen: $showingSectionMenu)
            }
            .sharedBackgroundVisibility(.hidden)
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
