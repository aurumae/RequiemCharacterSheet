//
//  CharacterListView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// The first screen: every saved character, with options to open, create, import, export and delete them.
struct CharacterListView: View {
    @Environment(\.theme) private var theme
    let store: CharacterStore

    @State private var openCharacter: OpenCharacter?
    @State private var pendingDeletion: CharacterSummary?
    @State private var errorAlert: ErrorAlert?
    @State private var choosingNewCharacter = false
    @State private var showingAbout = false
    @State private var choosingImportFile = false
    /// An imported character that's already on this device, waiting for Replace or Keep Both.
    @State private var conflictingImport: CharacterImport?
    /// A file opened from outside the app while a character was open; imported once that character is saved.
    @State private var waitingImportURL: URL?

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
                                    .contextMenu {
                                        if summary.isReadable {
                                            ShareLink(
                                                item: CharacterFile(url: store.exportURL(for: summary.id), name: summary.name),
                                                preview: SharePreview(displayName(for: summary))
                                            ) {
                                                Label("Export", systemImage: "square.and.arrow.up")
                                            }
                                        }
                                    }
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

                            AddRowButton("Import Character", systemImage: "square.and.arrow.down") {
                                choosingImportFile = true
                            }
                            .fileImporter(isPresented: $choosingImportFile, allowedContentTypes: [.requiemCharacter, .json]) { result in
                                switch result {
                                case .success(let url):
                                    importFile(at: url)
                                case .failure(let error):
                                    errorAlert = ErrorAlert(title: "Couldn't Import Character", message: error.localizedDescription)
                                }
                            }
                        }
                    }
                    .listStyle(.grouped)
                    .pageBorderEdge()

                    // The Dark Pack notice and the bundled fonts' licences
                    Button("About") {
                        showingAbout = true
                    }
                    .themedText(.label)
                    .padding(.vertical, 6)
                    .sheet(isPresented: $showingAbout) {
                        AboutView()
                    }
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
                    if let url = waitingImportURL {
                        waitingImportURL = nil
                        importFile(at: url)
                    }
                }
            }
            // A character file opened from Files, Mail, AirDrop and so on
            .onOpenURL { url in
                if openCharacter != nil {
                    // Save and close the open character first, so the import can't be overwritten by it
                    waitingImportURL = url
                    openCharacter = nil
                } else {
                    importFile(at: url)
                }
            }
            .alert(
                "“\(conflictingImport.map { displayName(for: $0.character.name) } ?? "")” Is Already Here",
                isPresented: Binding(
                    get: { conflictingImport != nil },
                    set: { if !$0 { conflictingImport = nil } }
                ),
                presenting: conflictingImport
            ) { pending in
                Button("Replace", role: .destructive) { finishImport(pending, keepingBoth: false) }
                Button("Keep Both") { finishImport(pending, keepingBoth: true) }
                Button("Cancel", role: .cancel) {}
            } message: { pending in
                Text(conflictMessage(for: pending))
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
        displayName(for: summary.name)
    }

    private func displayName(for name: String) -> String {
        name.isEmpty ? "Unnamed Character" : name
    }

    private func conflictMessage(for pending: CharacterImport) -> String {
        let imported = "The imported copy was edited \(pending.character.modifiedAt.formatted(date: .abbreviated, time: .shortened))."
        guard let here = pending.existing?.modifiedAt else { return imported }
        return imported + " The one on this device was edited \(here.formatted(date: .abbreviated, time: .shortened))."
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

    private func importFile(at url: URL) {
        // Files chosen in the picker are outside the app, and need permission to read
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let data = try Data(contentsOf: url)
            // Files opened from other apps arrive as a copy inside the app's own storage, no longer needed
            if [URL.documentsDirectory, URL.temporaryDirectory].contains(where: { url.path.hasPrefix($0.path) }) {
                try? FileManager.default.removeItem(at: url)
            }
            let pending = try store.prepareImport(of: data)
            if pending.isAlreadyHere {
                // Nothing to ask: the character here is the same, so just show it
                openCharacter = OpenCharacter(character: try store.load(pending.character.id))
            } else if pending.existing == nil {
                finishImport(pending, keepingBoth: false)
            } else {
                conflictingImport = pending
            }
        } catch {
            errorAlert = ErrorAlert(title: "Couldn't Import Character", message: error.localizedDescription)
        }
    }

    /// Adds the character to the store and opens it.
    private func finishImport(_ pending: CharacterImport, keepingBoth: Bool) {
        do {
            let id = try store.importCharacter(pending, keepingBoth: keepingBoth)
            openCharacter = OpenCharacter(character: try store.load(id))
        } catch {
            errorAlert = ErrorAlert(title: "Couldn't Import Character", message: error.localizedDescription)
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
