//
//  MeritDetailView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// A catalog Merit's details: ratings, qualifier, prerequisites (met or not), effects on the sheet,
/// and Fighting Style maneuvers.
struct MeritDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let merit: Merit
    let entry: MeritEntry
    let character: Character

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.summary)
                            .themedText(.body)
                        detail("Rating", entry.ratingsText)
                        if let qualifier = entry.qualifier {
                            detail(qualifier.prompt, merit.qualifier ?? "Not chosen")
                        }
                        Text(entry.source.citation())
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }

                let checks = character.prerequisiteChecks(for: entry)
                if !checks.isEmpty {
                    Section(header: Text("Prerequisites").themedText(.subsectionHeader)) {
                        ForEach(checks, id: \.description) { check in
                            Label {
                                Text(check.description)
                                    .themedText(.body)
                            } icon: {
                                Image(systemName: icon(for: check))
                                    .foregroundStyle(check.isMet == false ? theme.accent : theme.muted)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(check.description)
                            .accessibilityValue(accessibilityValue(for: check))
                        }
                    }
                }

                if !entry.effects.isEmpty {
                    Section(header: Text("On your sheet").themedText(.subsectionHeader)) {
                        ForEach(Array(entry.effects.enumerated()), id: \.offset) { _, effect in
                            Text(effect.description(rating: merit.rating, qualifier: merit.qualifier))
                                .themedText(.body)
                        }
                    }
                }

                if !entry.styleManeuvers.isEmpty {
                    Section(header: Text("Maneuvers").themedText(.subsectionHeader)) {
                        ForEach(entry.styleManeuvers, id: \.dots) { maneuver in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(maneuver.name)
                                        .themedText(.traitName)
                                    Spacer()
                                    Text(String(repeating: "●", count: maneuver.dots))
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.accent)
                                        .accessibilityLabel("\(maneuver.dots) \(maneuver.dots == 1 ? "dot" : "dots")")
                                }
                                Text(maneuver.summary)
                                    .themedText(.body)
                            }
                            .padding(.vertical, 4)
                            .opacity(maneuver.dots <= merit.rating ? 1 : 0.5)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .navigationTitle(merit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(theme.accent)
    }

    private func icon(for check: PrerequisiteCheck) -> String {
        switch check.isMet {
        case true?: return "checkmark.circle"
        case false?: return "exclamationmark.triangle"
        case nil: return "info.circle"
        }
    }

    private func accessibilityValue(for check: PrerequisiteCheck) -> String {
        switch check.isMet {
        case true?: return "Met"
        case false?: return "Not met"
        case nil: return "Check yourself"
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        (Text("\(label): ").bold() + Text(value))
            .themedText(.detail)
    }
}
