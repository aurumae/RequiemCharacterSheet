//
//  CharacterListView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// The first screen: every saved character, with options to open, create and delete them.
struct CharacterListView: View {
    let store: CharacterStore

    @State private var openCharacter: OpenCharacter?
    @State private var pendingDeletion: CharacterSummary?
    @State private var errorAlert: ErrorAlert?

    var body: some View {
        NavigationStack {
            BackgroundView {
                VStack {
                    Spacer(minLength: 20)
                    Image("VtR 2nd ED Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                    Spacer(minLength: 20)

                    List {
                        Section(header: Text("CHARACTERS").font(.custom("CaslonAntique", size: 24))) {
                            if store.summaries.isEmpty {
                                Text("No characters yet")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
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

                            Button(action: createCharacter) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text("New Character")
                                }
                                .foregroundColor(.vampireRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(GroupedListStyle())
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
        .tint(.vampireRed)
    }

    @ViewBuilder
    private func row(for summary: CharacterSummary) -> some View {
        if summary.isReadable {
            Button {
                open(summary)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName(for: summary))
                        .vampireFont()
                    let details = [summary.clan, summary.covenant].filter { !$0.isEmpty }
                    if !details.isEmpty {
                        Text(details.joined(separator: " · "))
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                    }
                    if let modifiedAt = summary.modifiedAt {
                        Text("Edited \(modifiedAt, format: .relative(presentation: .named))")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Couldn't open this character")
                    .font(.system(size: 16))
                Text("It may be damaged, or saved by a newer version of the app.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func displayName(for summary: CharacterSummary) -> String {
        summary.name.isEmpty ? "Unnamed Character" : summary.name
    }

    // MARK: - Actions

    private func createCharacter() {
        let character = Character()
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
