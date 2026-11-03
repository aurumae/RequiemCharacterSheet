//
//  CatalogPickerView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// One choice in a `CatalogPickerView`.
struct CatalogPickerItem: Identifiable {
    let id: CatalogEntryID
    let name: String
    /// Shown as dots beside the name, e.g. a ritual's rating.
    var dots: Int?
    let summary: String
    /// Short facts, e.g. "Costs 2 Experiences".
    var details: [String] = []
    /// A rule the character doesn't meet. The item can still be chosen.
    var warning: String?
    let citation: String
    /// Already on the sheet, so shown ticked and not chosen again.
    var isOwned = false
}

struct CatalogPickerSection: Identifiable {
    var id: String { title }
    let title: String
    let items: [CatalogPickerItem]
}

/// A "Custom …" choice at the end of a picker, for homebrew or entries that aren't listed.
struct CatalogPickerCustomOption: Identifiable {
    let id: String
    let title: String
    var subtitle = "For homebrew, or one that isn't listed."
}

/// A searchable list of catalog entries in sections, with custom options at the end.
struct CatalogPickerView: View {
    enum Choice {
        case entry(CatalogEntryID)
        /// The id of the chosen custom option.
        case custom(String)
    }

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let title: String
    let searchPrompt: String
    let sections: [CatalogPickerSection]
    let customOptions: [CatalogPickerCustomOption]
    let onChoose: (Choice) -> Void

    @State private var searchText = ""

    /// When searching, items whose name matches come before those whose summary does.
    private func matching(_ items: [CatalogPickerItem]) -> [CatalogPickerItem] {
        guard !searchText.isEmpty else { return items }
        let nameMatches = items.filter { $0.name.localizedStandardContains(searchText) }
        let summaryMatches = items.filter {
            !$0.name.localizedStandardContains(searchText) && $0.summary.localizedStandardContains(searchText)
        }
        return nameMatches + summaryMatches
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    let items = matching(section.items)
                    if !items.isEmpty {
                        Section(header: Text(section.title).themedText(.subsectionHeader)) {
                            ForEach(items) { item in
                                row(for: item)
                            }
                        }
                    }
                }

                Section {
                    ForEach(customOptions) { option in
                        Button {
                            choose(.custom(option.id))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .themedText(.traitName)
                                Text(option.subtitle)
                                    .themedText(.detail)
                                    .foregroundStyle(theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $searchText, prompt: searchPrompt)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(theme.accent)
    }

    private func row(for item: CatalogPickerItem) -> some View {
        Button {
            choose(.entry(item.id))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                            .themedText(.traitName)
                        if let dots = item.dots {
                            DotsText(dots)
                        }
                    }
                    Text(item.summary)
                        .themedText(.detail)
                        .foregroundStyle(.primary)
                    ForEach(item.details, id: \.self) { detail in
                        Text(detail)
                            .themedText(.detail)
                    }
                    if let warning = item.warning {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .themedText(.detail)
                            .foregroundStyle(theme.accent)
                    }
                    Text(item.citation)
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                }
                Spacer()
                if item.isOwned {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                        .accessibilityLabel("Already on the sheet")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(item.isOwned)
    }

    private func choose(_ choice: Choice) {
        onChoose(choice)
        dismiss()
    }
}

/// A fixed rating written as dots, e.g. "●●" for a two-dot ritual.
struct DotsText: View {
    @Environment(\.theme) private var theme
    let count: Int

    init(_ count: Int) {
        self.count = count
    }

    var body: some View {
        Text(String(repeating: "●", count: count))
            .font(.system(size: 12))
            .foregroundStyle(theme.accent)
            .accessibilityLabel("\(count) \(count == 1 ? "dot" : "dots")")
    }
}

/// One labelled fact on a detail sheet, e.g. "Cost: 1 Vitae".
struct DetailFact: Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

/// A catalog entry's details: summary, source, facts, warnings, and anything else the caller adds below.
struct CatalogDetailView<Extra: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let title: String
    let summary: String
    let citation: String
    var facts: [DetailFact] = []
    var warnings: [String] = []
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary)
                            .themedText(.body)
                        ForEach(facts) { fact in
                            (Text("\(fact.label): ").bold() + Text(fact.value))
                                .themedText(.detail)
                        }
                        ForEach(warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .themedText(.detail)
                                .foregroundStyle(theme.accent)
                        }
                        Text(citation)
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }

                extra()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(theme.accent)
    }
}

extension CatalogDetailView where Extra == EmptyView {
    init(title: String, summary: String, citation: String, facts: [DetailFact] = [], warnings: [String] = []) {
        self.init(title: title, summary: summary, citation: citation, facts: facts, warnings: warnings) { EmptyView() }
    }
}

/// A warning under a row, e.g. "Requires Crúac 3".
struct RowWarning: View {
    @Environment(\.theme) private var theme
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .themedText(.detail)
            .foregroundStyle(theme.accent)
    }
}
