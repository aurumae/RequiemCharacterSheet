//
//  CharacterListView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// The first screen: every saved character, with options to open, create and delete them.
struct CharacterListView: View {
    @Environment(\.theme) private var theme
    let store: CharacterStore

    @State private var openCharacter: OpenCharacter?
    @State private var pendingDeletion: CharacterSummary?
    @State private var errorAlert: ErrorAlert?
    @State private var choosingNewCharacter = false

    var body: some View {
        NavigationStack {
            BackgroundView {
                VStack {
                    Spacer(minLength: 20)
                    LogoHeader()
                    Spacer(minLength: 20)

                    List {
                        Section(header: Text("CHARACTERS").themedText(.sectionHeader)) {
                            if store.summaries.isEmpty {
                                Text("No characters yet")
                                    .themedText(.body)
                                    .foregroundStyle(theme.muted)
                            }

                            ForEach(store.summaries) { summary in
                                row(for: summary)
                                    .swipeActions {
                                        Button("Delete") {
                                            pendingDeletion = summary
                                        }
                                        .tint(.red)
                                    }
                                    // Attached per row so the confirmation appears next to the row being deleted
                                    .confirmationDialog(
                                        "Delete this character?",
                                        isPresented: Binding(
                                            get: { pendingDeletion?.id == summary.id },
                                            set: { if !$0 { pendingDeletion = nil } }
                                        ),
                                        titleVisibility: .visible
                                    ) {
                                        Button("Delete \(displayName(for: summary))", role: .destructive) {
                                            delete(summary)
                                        }
                                        Button("Cancel", role: .cancel) {}
                                    } message: {
                                        Text("This can't be undone.")
                                    }
                            }

                            AddRowButton("New Character") {
                                choosingNewCharacter = true
                            }
                            .confirmationDialog("New Character", isPresented: $choosingNewCharacter, titleVisibility: .visible) {
                                Button("Guided Character Creation") { createCharacter(guided: true) }
                                Button("Blank Sheet") { createCharacter(guided: false) }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("Guided creation walks through the book's steps and keeps to the starting dots. A blank sheet has no limits, e.g. for a character you already have.")
                            }
                        }
                    }
                    .listStyle(.grouped)
                    .pageBorderEdge()
                }
                .padding(.horizontal)
                .padding(.bottom, 26)
            }
            // Used as the sheet's back button title
            .navigationTitle("Characters")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $openCharacter) { open in
                CharacterSheetView(character: open.character, store: store)
            }
            // Leaving the sheet (back button or swipe) keeps the changes
            .onChange(of: openCharacter) { closed, nowOpen in
                if nowOpen == nil, let closed {
                    save(closed.character)
                }
            }
            .alert(
                errorAlert?.title ?? "",
                isPresented: Binding(
                    get: { errorAlert != nil },
                    set: { if !$0 { errorAlert = nil } }
                ),
                presenting: errorAlert
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { alert in
                Text(alert.message)
            }
        }
        .tint(theme.accent)
    }

    @ViewBuilder
    private func row(for summary: CharacterSummary) -> some View {
        if summary.isReadable {
            Button {
                open(summary)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName(for: summary))
                        .themedText(.label)
                    let details = [summary.clan, summary.covenant].filter { !$0.isEmpty }
                    if !details.isEmpty {
                        Text(details.joined(separator: " · "))
                            .themedText(.body)
                    }
                    if let modifiedAt = summary.modifiedAt {
                        Text("Edited \(modifiedAt, format: .relative(presentation: .named))")
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Couldn't open this character")
                    .themedText(.body)
                Text("It may be damaged, or saved by a newer version of the app.")
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 4)
        }
    }

    private func displayName(for summary: CharacterSummary) -> String {
        summary.name.isEmpty ? "Unnamed Character" : summary.name
    }

    // MARK: - Actions

    private func createCharacter(guided: Bool) {
        let character = guided ? Character.guided() : Character()
        do {
            try store.save(character)
        } catch {
            errorAlert = ErrorAlert(title: "Couldn't Create Character", message: error.localizedDescription)
            return
        }
        openCharacter = OpenCharacter(character: character)
    }

    private func open(_ summary: CharacterSummary) {
        do {
            openCharacter = OpenCharacter(character: try store.load(summary.id))
        } catch {
            errorAlert = ErrorAlert(title: "Couldn't Open Character", message: error.localizedDescription)
        }
    }

    private func save(_ character: Character) {
        do {
            try store.save(character)
        } catch {
            errorAlert = ErrorAlert(title: "Couldn't Save Character", message: error.localizedDescription)
        }
    }

    private func delete(_ summary: CharacterSummary) {
        do {
            try store.delete(summary.id)
        } catch {
            errorAlert = ErrorAlert(title: "Couldn't Delete Character", message: error.localizedDescription)
        }
    }
}

/// Lets a `Character` (a class) drive navigation, compared by identity.
private struct OpenCharacter: Hashable {
    let character: Character

    static func == (lhs: OpenCharacter, rhs: OpenCharacter) -> Bool {
        lhs.character === rhs.character
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(character))
    }
}

private struct ErrorAlert {
    let title: String
    let message: String
}
