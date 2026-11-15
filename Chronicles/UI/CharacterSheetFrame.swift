//
//  CharacterSheetFrame.swift
//  Chronicles
//

import SwiftUI

/// What every game's character sheet has round its rows: the logo, the watermark, the scrolling list, the section
/// pill and its list, and saving (with the Save button, when leaving the app, and when the sheet closes).
struct CharacterSheetFrame<C: StoredCharacter, Rows: View>: View {
    let character: C
    let store: CharacterFileStore<C>
    /// The sections the sheet shows, in order.
    let sections: [SheetSection]
    @ViewBuilder let rows: Rows

    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSavedConfirmation = false
    @State private var saveErrorMessage: String?
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
                        rows
                    }
                    .listStyle(.grouped)
                    .listSectionSpacing(15)
                    .themedListBackground(theme)
                    // Scrolling ends text editing
                    .scrollDismissesKeyboard(.immediately)
                    .sheetWatermark()
                    .pageBorderEdge()
                    .environment(\.defaultMinListRowHeight, 36)
                    // A field opening for editing is scrolled clear of the keyboard
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
                        if let current = sectionTracker.currentSection(in: sections), current != currentSection {
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
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 26)
        }
        .overlay {
            if showingSectionMenu {
                SectionMenu(sections: sections, current: currentSection) { section in
                    showingSectionMenu = false
                    currentSection = section
                    jumpedSection = section
                    sectionToShow = section
                } close: {
                    withAnimation(.snappy(duration: 0.2)) { showingSectionMenu = false }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // Jumps between the sheet's sections
            ToolbarItem(placement: .topBarLeading) {
                SectionPill(current: currentSection, isOpen: $showingSectionMenu)
            }
            .sharedBackgroundVisibility(.hidden)
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
