//
//  WerewolfSections.swift
//  ForsakenCharacterSheet
//
//  The sections only a Forsaken sheet has: the character's auspice, tribe and lodge, form, Renown, Gifts, Rites,
//  fetishes, Primal Urge and Essence, Harmony and Touchstones, and Kuruth triggers.
//

import SwiftUI

extension SheetSection {
    static let form = SheetSection("form", title: "Form")
    static let renown = SheetSection("renown", title: "Renown")
    static let moonGifts = SheetSection("moonGifts", title: "Moon Gifts")
    static let shadowGifts = SheetSection("shadowGifts", title: "Shadow Gifts")
    static let wolfGifts = SheetSection("wolfGifts", title: "Wolf Gifts")
    static let rites = SheetSection("rites", title: "Rites")
    static let fetishes = SheetSection("fetishes", title: "Fetishes")
    static let primalUrge = SheetSection("primalUrge", title: "Primal Urge")
    static let harmony = SheetSection("harmony", title: "Harmony")
    static let kuruth = SheetSection("kuruth", title: "Kuruth", heading: "Kuruth Triggers")
}

/// A picker's sections for catalog entries: one per book, and within it one per group.
private func pickerSections<Entry: CatalogEntry>(_ groups: [CatalogPickerGroup<Entry>],
                                                  item: (Entry) -> CatalogPickerItem = { entry in
    CatalogPickerItem(id: entry.id, name: entry.name, summary: entry.summary, citation: entry.source.citation())
}) -> [CatalogPickerSection] {
    CatalogPickerSection.byBook(groups, books: Catalog.bundled.books, item: item)
}

private func giftName(_ id: CatalogEntryID) -> String {
    Catalog.bundled.gifts.entry(id)?.name ?? id
}

// MARK: - Character

/// The Character section: the details at the top of the official sheet, in its order.
struct ForsakenCharacterInfoView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter

    var body: some View {
        SheetSectionBlock(.character) {
            CharacterInfoRowView(label: "Name:", text: $character.name)
            CharacterInfoRowView(label: "Player:", text: $character.player)
            CharacterInfoRowView(label: "Chronicle:", text: $character.chronicle)
            archetypeRow("Blood:", kind: .blood, source: $character.bloodSource)
            archetypeRow("Bone:", kind: .bone, source: $character.boneSource)
            CharacterInfoRowView(label: "Concept:", text: $character.concept)
            // The Pure have no auspice, and take a Hunter's Aspect from their tribe instead
            if character.isPure {
                pureHuntersAspectRow
            } else {
                auspiceRow
            }
            tribeRow
            lodgeRow
            if Catalog.bundled.books.hasUnofficial {
                UnofficialContentRow(isOn: $character.showsUnofficialContent)
            }
        }
    }

    private func archetypeRow(_ label: String, kind: ArchetypeEntry.Kind, source: Binding<TraitSource>) -> some View {
        let catalog = Catalog.bundled.archetypes
        let title = kind == .blood ? "Blood" : "Bone"
        return CatalogChoiceRow(
            label: label,
            value: catalog.name(of: source.wrappedValue),
            isCustom: source.wrappedValue.catalogID == nil,
            setCustomText: { source.wrappedValue = catalog.source(named: $0) },
            pickerTitle: title,
            searchPrompt: "Search \(title) archetypes",
            sections: { pickerSections([CatalogPickerGroup("", catalog.all.filter { $0.kind == kind })]) },
            customTitle: "Custom \(title)",
            detail: {
                source.wrappedValue.catalogID.flatMap { catalog.entry($0) }.map {
                    CatalogChoiceDetail(title: $0.name, summary: $0.summary, citation: $0.source.citation())
                }
            },
            choose: { id in source.wrappedValue = id.map { .catalog($0) } ?? .custom("") }
        )
    }

    private var auspiceRow: some View {
        let catalog = Catalog.bundled.auspices
        return CatalogChoiceRow(
            label: "Auspice:",
            value: character.auspice,
            isCustom: character.auspiceSource.catalogID == nil,
            setCustomText: { character.auspice = $0 },
            pickerTitle: "Auspice",
            searchPrompt: "Search auspices",
            sections: { pickerSections([CatalogPickerGroup("", catalog.all)]) },
            customTitle: "Custom Auspice",
            // The Pure have none
            noneTitle: "No Auspice",
            detail: {
                character.auspiceEntry.map { auspice in
                    CatalogChoiceDetail(title: auspice.name, summary: auspice.summary, citation: auspice.source.citation(), facts: [
                        DetailFact(label: "Moon", value: auspice.moon.capitalized),
                        DetailFact(label: "Renown", value: auspice.renown.name),
                        DetailFact(label: "Skills", value: auspice.skills.compactMap { SkillDefinition.withID($0)?.name }.joined(separator: ", ")),
                        DetailFact(label: "Moon Gift", value: giftName(auspice.moonGift)),
                        DetailFact(label: "Shadow Gifts", value: auspice.giftAffinities.map(giftName).joined(separator: ", ")),
                        DetailFact(label: "Hunter's Aspect", value: "\(auspice.huntersAspect.name), inflicting \(Catalog.bundled.conditions.entry(auspice.huntersAspect.condition)?.name ?? auspice.huntersAspect.condition)"),
                    ])
                }
            },
            choose: { id in
                let source: TraitSource = id.map { .catalog($0) } ?? .custom("")
                // An alternate Moon Gift belongs to one auspice, so it goes back to the new auspice's own
                if source != character.auspiceSource {
                    character.moonGiftSource = nil
                }
                character.auspiceSource = source
            }
        )
    }

    private var tribeRow: some View {
        let catalog = Catalog.bundled.tribes
        return CatalogChoiceRow(
            label: "Tribe:",
            value: character.tribe,
            isCustom: character.tribeSource.catalogID == nil,
            setCustomText: { character.tribe = $0 },
            pickerTitle: "Tribe",
            searchPrompt: "Search tribes",
            sections: {
                pickerSections([
                    CatalogPickerGroup("Forsaken", catalog.all.filter { $0.kind == .forsaken }),
                    CatalogPickerGroup("Tribeless", catalog.all.filter { $0.kind == .ghostWolf }),
                    CatalogPickerGroup("Pure", catalog.all.filter { $0.kind == .pure }),
                ])
            },
            customTitle: "Custom Tribe",
            detail: {
                character.tribeEntry.map { tribe in
                    var facts: [DetailFact] = []
                    if let renown = tribe.renown {
                        facts.append(DetailFact(label: "Renown", value: renown.name))
                    }
                    if let secondary = tribe.secondaryRenown, !secondary.isEmpty {
                        facts.append(DetailFact(label: "Secondary Renown", value: secondary.map(\.name).joined(separator: ", ")))
                    }
                    if let skills = tribe.skills, !skills.isEmpty {
                        facts.append(DetailFact(label: "Skills", value: skills.compactMap { SkillDefinition.withID($0)?.name }.joined(separator: ", ")))
                    }
                    if let aspects = tribe.huntersAspects, !aspects.isEmpty {
                        let names = aspects.map { "\($0.name), inflicting \(Catalog.bundled.conditions.entry($0.condition)?.name ?? $0.condition)" }
                        facts.append(DetailFact(label: "Hunter's Aspects", value: names.joined(separator: "; ")))
                    }
                    if !tribe.giftAffinities.isEmpty {
                        facts.append(DetailFact(label: "Shadow Gifts", value: tribe.giftAffinities.map(giftName).joined(separator: ", ")))
                    }
                    if let oath = tribe.oath {
                        facts.append(DetailFact(label: tribe.kind == .pure ? "Restriction" : "Oath", value: "\(oath.name). \(oath.summary)"))
                    }
                    return CatalogChoiceDetail(title: tribe.name, summary: tribe.summary, citation: tribe.source.citation(), facts: facts)
                }
            },
            choose: { id in
                let source: TraitSource = id.map { .catalog($0) } ?? .custom("")
                // A Hunter's Aspect belongs to one tribe, so it's chosen again after a change
                if source != character.tribeSource {
                    character.pureHuntersAspect = ""
                }
                character.tribeSource = source
            }
        )
    }

    /// A Pure character's choice between their tribe's two Hunter's Aspects, styled like the other choice rows.
    private var pureHuntersAspectRow: some View {
        let aspects = character.tribeEntry?.huntersAspects ?? []
        let value = character.huntersAspect?.name ?? ""
        return HStack {
            Text("Hunter's Aspect:")
                .themedText(.label)
                .frame(minWidth: 100, alignment: .leading)
            Spacer()
            Menu {
                ForEach(aspects, id: \.name) { aspect in
                    Button {
                        character.pureHuntersAspect = aspect.name
                    } label: {
                        let condition = Catalog.bundled.conditions.entry(aspect.condition)?.name ?? aspect.condition
                        Text(aspect.name)
                        Text("Inflicts \(condition)")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(value.isEmpty ? "Choose" : value)
                        .themedText(.body)
                        .foregroundStyle(value.isEmpty ? theme.muted : Color.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hunter's Aspect")
            .accessibilityValue(value.isEmpty ? "Not chosen" : value)
        }
        .padding(.vertical, 4)
        .editingRow("info-Hunter's Aspect")
    }

    private var lodgeRow: some View {
        let catalog = Catalog.bundled.lodges
        return CatalogChoiceRow(
            label: "Lodge:",
            value: character.lodge,
            isCustom: character.lodgeSource.catalogID == nil,
            setCustomText: { character.lodge = $0 },
            pickerTitle: "Lodge",
            searchPrompt: "Search lodges",
            sections: {
                pickerSections([CatalogPickerGroup("", catalog.all)]) { lodge in
                    let limits = (lodge.auspices ?? []).compactMap { Catalog.bundled.auspices.entry($0)?.name }
                        + (lodge.tribes ?? []).compactMap { Catalog.bundled.tribes.entry($0)?.name }
                    return CatalogPickerItem(id: lodge.id, name: lodge.name, summary: lodge.summary,
                                             details: limits.isEmpty ? [] : ["\(limits.joined(separator: ", ")) only"],
                                             citation: lodge.source.citation())
                }
            },
            customTitle: "Custom Lodge",
            noneTitle: "No Lodge",
            detail: {
                character.lodgeSource.catalogID.flatMap { catalog.entry($0) }.map {
                    CatalogChoiceDetail(title: $0.name, summary: $0.summary, citation: $0.source.citation())
                }
            },
            choose: { id in character.lodgeSource = id.map { .catalog($0) } ?? .custom("") }
        )
    }
}

// MARK: - Form

/// The five forms, and what the current one does.
struct FormView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter

    var body: some View {
        SheetSectionBlock(.form) {
            Picker("Form", selection: $character.form) {
                ForEach(Form.allCases) { form in
                    Text(form.name).tag(form)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                let form = character.form
                Text(form.description)
                    .themedText(.ratedTrait)
                let changes = AttributeKind.allCases.compactMap { kind -> String? in
                    guard let change = form.attributeModifiers[kind] else { return nil }
                    return "\(kind.name) \(change > 0 ? "+" : "−")\(abs(change))"
                }
                + (form.sizeModifier != 0 ? ["Size \(form.sizeModifier > 0 ? "+" : "−")\(abs(form.sizeModifier))"] : [])
                + (form.speciesSpeedBonus > 0 ? ["Speed +\(form.speciesSpeedBonus) more"] : [])
                + ["Perception +\(form.perceptionBonus)"]
                Text(changes.joined(separator: " · "))
                    .themedText(.detail)
                Text(form.notes)
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Renown

struct RenownView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter

    var body: some View {
        SheetSectionBlock(.renown) {
            ForEach(Renown.allCases) { kind in
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(kind.name)
                            .themedText(.ratedTrait)
                        if let note = note(for: kind) {
                            Text(note)
                                .themedText(.detail)
                                .foregroundStyle(theme.muted)
                        }
                    }
                    Spacer()
                    DotsRatingView(
                        kind.name,
                        rating: Binding(get: { character.renown(kind) }, set: { character.setRenown(kind, to: $0) }),
                        maxRating: 5,
                        allowsResetToZero: true
                    )
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// Which of the character's auspice and tribe favour it.
    private func note(for kind: Renown) -> String? {
        let givers = [character.effectiveAuspice?.renown == kind ? "Auspice" : nil,
                      character.tribeEntry?.renown == kind ? "Tribe" : nil].compactMap { $0 }
        if givers.isEmpty {
            // The Pure's second starting dot can go to one of these instead (Shunned by the Moon, p. 14)
            return character.tribeEntry?.secondaryRenown?.contains(kind) == true ? "Secondary Tribe Renown" : nil
        }
        return givers.joined(separator: " and ") + " Renown"
    }
}

// MARK: - Gifts

/// The Moon Gift the character uses, and its Facets: one for each dot of auspice Renown, unlocked automatically.
struct MoonGiftView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter
    @State private var shownFacet: (gift: GiftEntry, facet: GiftEntry.Facet)?

    var body: some View {
        SheetSectionBlock(.moonGifts) {
            moonGiftRow
            if let gift = character.moonGift {
                ForEach(gift.facets.sorted { ($0.dots ?? 0) < ($1.dots ?? 0) }) { facet in
                    let dots = facet.dots ?? 0
                    Button {
                        shownFacet = (gift, facet)
                    } label: {
                        facetLabel(name: Text(facet.name), dots: dots)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows its details")
                }
            } else if case .custom = character.moonGiftSource {
                ForEach(1...5, id: \.self) { dots in
                    facetLabel(name: TapToEditText("Facet Name", accessibilityName: "\(dots)-dot Facet",
                                                   text: customFacetName(dots)), dots: dots)
                        .editingRow("moon-facet-\(dots)")
                }
            }
        }
        .hostedSheet(isPresented: Binding(get: { shownFacet != nil }, set: { if !$0 { shownFacet = nil } })) {
            if let shownFacet {
                CatalogDetailView(title: shownFacet.facet.name, summary: shownFacet.facet.summary,
                                  citation: shownFacet.facet.source.citation(), facts: facetFacts(shownFacet.gift, shownFacet.facet))
            }
        }
    }

    /// A Facet beside its dots, muted until auspice Renown reaches them.
    private func facetLabel(name: some View, dots: Int) -> some View {
        let unlocked = dots <= character.moonGiftDots
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                name.themedText(.traitName)
                if !unlocked, let renown = character.moonGiftRenown {
                    Text("Unlocks at \(renown.name) \(dots)")
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                }
            }
            Spacer()
            Text(String(repeating: "●", count: dots))
                .foregroundStyle(theme.accent)
                .accessibilityLabel(dots == 1 ? "1 dot" : "\(dots) dots")
        }
        .opacity(unlocked ? 1 : 0.45)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityValue(unlocked ? "Unlocked" : "Locked")
    }

    private func customFacetName(_ dots: Int) -> Binding<String> {
        Binding(
            get: { character.customMoonFacets.indices.contains(dots - 1) ? character.customMoonFacets[dots - 1] : "" },
            set: { name in
                var names = character.customMoonFacets
                while names.count < dots { names.append("") }
                names[dots - 1] = name
                // Trailing empty names aren't kept
                while names.last?.isEmpty == true { names.removeLast() }
                character.customMoonFacets = names
            }
        )
    }

    /// The auspice's own Moon Gifts first, e.g. the core book's and any alternates, then the rest.
    private var moonGiftRow: some View {
        let moonGifts = Catalog.bundled.gifts.all.filter { $0.kind == .moon }
        let auspice = character.effectiveAuspice?.id
        let isCustom: Bool = if case .custom = character.moonGiftSource { true } else { false }
        return CatalogChoiceRow(
            label: "Moon Gift:",
            value: character.moonGiftName,
            isCustom: isCustom,
            setCustomText: { character.moonGiftSource = .custom($0) },
            pickerTitle: "Moon Gift",
            searchPrompt: "Search Moon Gifts",
            sections: {
                pickerSections([
                    CatalogPickerGroup(auspice == nil ? "" : "Your Auspice", moonGifts.filter { $0.auspice == auspice }),
                    CatalogPickerGroup(auspice == nil ? "" : "Other Auspices", moonGifts.filter { $0.auspice != auspice }),
                ]) { gift in
                    let auspiceName = gift.auspice.flatMap { Catalog.bundled.auspices.entry($0)?.name }
                    return CatalogPickerItem(id: gift.id, name: gift.name, summary: gift.summary,
                                             details: auspiceName.map { ["\($0) only"] } ?? [],
                                             citation: gift.source.citation())
                }
            },
            customTitle: "Custom Moon Gift",
            detail: {
                character.moonGift.map {
                    CatalogChoiceDetail(title: $0.name, summary: $0.summary, citation: $0.source.citation())
                }
            },
            choose: { id in
                // The auspice's own Moon Gift is the default, so isn't stored
                let ownID = character.effectiveAuspice?.moonGift
                if let id {
                    character.moonGiftSource = id == ownID ? nil : .catalog(id)
                } else {
                    character.moonGiftSource = .custom("")
                }
            }
        )
    }
}

/// The Shadow or Wolf Gift Facets the character knows, and adding more.
struct GiftsView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter
    /// `.shadow` or `.wolf`.
    let kind: GiftEntry.Kind
    @State private var showingPicker = false
    @State private var shownFacet: (gift: GiftEntry, facet: GiftEntry.Facet)?
    /// A custom Facet that was just added, whose name opens for editing.
    @State private var newCustomFacetID: UUID?
    @State private var addsCustomOnDismiss = false

    private var kindName: String {
        kind == .wolf ? "Wolf" : "Shadow"
    }

    /// The character's Facets of this kind of Gift.
    private var facets: [OwnedFacet] {
        character.facets.filter { (character.gift(of: $0)?.kind ?? $0.customKind) == kind }
    }

    var body: some View {
        SheetSectionBlock(kind == .wolf ? .wolfGifts : .shadowGifts) {
            ForEach(facets) { owned in
                row(for: owned)
                    .editingRow(owned.id)
            }
            .onDelete { offsets in
                let ids = Set(offsets.map { facets[$0].id })
                character.facets.removeAll { ids.contains($0.id) }
            }

            AddRowButton("Add \(kindName) Facet") {
                showingPicker = true
            }
            .hostedSheet(isPresented: $showingPicker, onDismiss: addCustomIfChosen) {
                CatalogPickerView(
                    title: "Add \(kindName) Facet",
                    searchPrompt: "Search \(kindName) Gifts and Facets",
                    sections: facetSections(),
                    customOptions: [CatalogPickerCustomOption(id: "custom", title: "Custom \(kindName) Facet")]
                ) { choice in
                    switch choice {
                    case .entry(let id):
                        character.facets.append(OwnedFacet(source: .catalog(id)))
                    case .custom:
                        addsCustomOnDismiss = true
                    }
                }
            }
        }
        .hostedSheet(isPresented: Binding(get: { shownFacet != nil }, set: { if !$0 { shownFacet = nil } })) {
            if let shownFacet {
                CatalogDetailView(title: shownFacet.facet.name, summary: shownFacet.facet.summary,
                                  citation: shownFacet.facet.source.citation(), facts: facetFacts(shownFacet.gift, shownFacet.facet))
            }
        }
    }

    @ViewBuilder
    private func row(for owned: OwnedFacet) -> some View {
        if let id = owned.source.catalogID, let found = Catalog.bundled.facet(id) {
            Button {
                shownFacet = found
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(found.facet.name)
                        .themedText(.traitName)
                    Text([found.gift.name, found.facet.renown?.name].compactMap { $0 }.joined(separator: " · "))
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows its details")
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                TapToEditText(placeholder: "Facet Name", text: Binding(
                    get: { if case .custom(let name) = owned.source { name } else { "" } },
                    set: { owned.source = .custom($0) }
                ), beginsEditing: owned.id == newCustomFacetID) { name in
                    Text(name).themedText(.traitName)
                }
                TapToEditText("Gift", accessibilityName: "Gift", text: Binding(get: { owned.customGift }, set: { owned.customGift = $0 }),
                              font: .detail)
            }
            .padding(.vertical, 4)
        }
    }

    /// The Gifts by book, each a section: for Shadow Gifts, the tribe's and auspice's first, then the others.
    private func facetSections() -> [CatalogPickerSection] {
        let gifts = Catalog.bundled.gifts.all.filter { $0.kind == kind }
        let ordered = gifts.filter { character.affinityGifts.contains($0.id) }
            + gifts.filter { !character.affinityGifts.contains($0.id) }
        let owned = Set(character.facets.compactMap(\.source.catalogID))
        return ordered.flatMap { gift in
            pickerSections([CatalogPickerGroup(sectionTitle(gift), gift.facets)]) { facet in
                CatalogPickerItem(
                    id: facet.id,
                    name: facet.name,
                    summary: facet.summary,
                    details: [facet.renown?.name, facet.cost].compactMap { $0 },
                    warning: facet.renown.flatMap { character.renown($0) == 0 ? "Needs \($0.name) 1" : nil },
                    citation: facet.source.citation(),
                    isOwned: owned.contains(facet.id)
                )
            }
        }
    }

    private func sectionTitle(_ gift: GiftEntry) -> String {
        character.affinityGifts.contains(gift.id) ? "\(gift.name) (Affinity)" : gift.name
    }

    private func addCustomIfChosen() {
        guard addsCustomOnDismiss else { return }
        addsCustomOnDismiss = false
        let facet = OwnedFacet(source: .custom(""), customKind: kind)
        newCustomFacetID = facet.id
        character.facets.append(facet)
    }
}

/// A Facet's details: its Gift, Renown or dots, cost, dice pool, action and duration.
private func facetFacts(_ gift: GiftEntry, _ facet: GiftEntry.Facet) -> [DetailFact] {
    var facts = [DetailFact(label: "Gift", value: gift.name)]
    if let renown = facet.renown { facts.append(DetailFact(label: "Renown", value: renown.name)) }
    if let dots = facet.dots { facts.append(DetailFact(label: "Dots", value: String(repeating: "●", count: dots))) }
    if let cost = facet.cost { facts.append(DetailFact(label: "Cost", value: cost)) }
    if let pool = facet.dicePool { facts.append(DetailFact(label: "Dice Pool", value: pool)) }
    if let action = facet.action { facts.append(DetailFact(label: "Action", value: action.capitalized)) }
    if let duration = facet.duration { facts.append(DetailFact(label: "Duration", value: duration)) }
    return facts
}

// MARK: - Rites

struct RitesView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter
    @State private var showingPicker = false
    @State private var shownRite: RiteEntry?
    @State private var newCustomRiteID: UUID?
    @State private var addsCustomOnDismiss = false

    var body: some View {
        SheetSectionBlock(.rites) {
            ForEach(character.rites) { rite in
                row(for: rite)
                    .editingRow(rite.id)
            }
            .onDelete { character.rites.remove(atOffsets: $0) }

            AddRowButton("Add Rite") {
                showingPicker = true
            }
            .hostedSheet(isPresented: $showingPicker, onDismiss: addCustomIfChosen) {
                let owned = Set(character.rites.compactMap(\.source.catalogID))
                let rites = Catalog.bundled.rites.all
                CatalogPickerView(
                    title: "Add Rite",
                    searchPrompt: "Search Rites",
                    sections: pickerSections([
                        CatalogPickerGroup("Wolf Rites", rites.filter { $0.kind == .wolf }),
                        CatalogPickerGroup("Pack Rites", rites.filter { $0.kind == .pack }),
                    ]) { rite in
                        CatalogPickerItem(id: rite.id, name: rite.name, dots: rite.rating, summary: rite.summary,
                                          details: rite.targetSuccesses.map { ["\($0) successes"] } ?? [],
                                          citation: rite.source.citation(), isOwned: owned.contains(rite.id))
                    },
                    customOptions: [CatalogPickerCustomOption(id: "custom", title: "Custom Rite")]
                ) { choice in
                    switch choice {
                    case .entry(let id):
                        character.rites.append(OwnedRite(source: .catalog(id)))
                    case .custom:
                        addsCustomOnDismiss = true
                    }
                }
            }
        }
        .hostedSheet(isPresented: Binding(get: { shownRite != nil }, set: { if !$0 { shownRite = nil } })) {
            if let rite = shownRite {
                CatalogDetailView(title: rite.name, summary: rite.summary, citation: rite.source.citation(), facts: [
                    DetailFact(label: "Rite", value: "\(rite.kind == .wolf ? "Wolf" : "Pack") rite, \(String(repeating: "●", count: rite.rating))"),
                ] + [rite.targetSuccesses.map { DetailFact(label: "Target", value: "\($0) successes") },
                     rite.duration.map { DetailFact(label: "Duration", value: $0) }].compactMap { $0 })
            }
        }
    }

    @ViewBuilder
    private func row(for rite: OwnedRite) -> some View {
        if let id = rite.source.catalogID, let entry = Catalog.bundled.rites.entry(id) {
            Button {
                shownRite = entry
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .themedText(.traitName)
                        Text(entry.kind == .wolf ? "Wolf rite" : "Pack rite")
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    }
                    Spacer()
                    DotsRatingView(entry.name, value: entry.rating, maxRating: 5)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // One element, so the name isn't read twice with the dots
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.name), \(entry.kind == .wolf ? "Wolf" : "Pack") rite, \(entry.rating) \(entry.rating == 1 ? "dot" : "dots")")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Shows its details")
            .padding(.vertical, 4)
        } else {
            HStack {
                TapToEditText(placeholder: "Rite Name", text: Binding(
                    get: { if case .custom(let name) = rite.source { name } else { "" } },
                    set: { rite.source = .custom($0) }
                ), beginsEditing: rite.id == newCustomRiteID) { name in
                    Text(name).themedText(.traitName)
                }
                Spacer()
                DotsRatingView("Rite", rating: Binding(get: { rite.customRating }, set: { rite.customRating = max($0, 1) }), maxRating: 5)
            }
            .padding(.vertical, 4)
        }
    }

    private func addCustomIfChosen() {
        guard addsCustomOnDismiss else { return }
        addsCustomOnDismiss = false
        let rite = OwnedRite(source: .custom(""))
        newCustomRiteID = rite.id
        character.rites.append(rite)
    }
}

// MARK: - Fetishes

struct FetishesView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter
    @State private var showingPicker = false
    @State private var shownFetish: FetishEntry?
    @State private var newCustomFetishID: UUID?
    @State private var addsCustomOnDismiss = false

    var body: some View {
        SheetSectionBlock(.fetishes) {
            ForEach(character.fetishes) { fetish in
                row(for: fetish)
                    .editingRow(fetish.id)
            }
            .onDelete { character.fetishes.remove(atOffsets: $0) }

            AddRowButton("Add Fetish") {
                showingPicker = true
            }
            .hostedSheet(isPresented: $showingPicker, onDismiss: addCustomIfChosen) {
                let fetishes = Catalog.bundled.fetishes.all
                CatalogPickerView(
                    title: "Add Fetish",
                    searchPrompt: "Search fetishes and talens",
                    sections: pickerSections([
                        CatalogPickerGroup("Fetishes", fetishes.filter { $0.kind == .fetish }),
                        CatalogPickerGroup("Talens", fetishes.filter { $0.kind == .talen }),
                    ]) { fetish in
                        CatalogPickerItem(id: fetish.id, name: fetish.name, dots: fetish.rating, summary: fetish.summary,
                                          citation: fetish.source.citation())
                    },
                    customOptions: [CatalogPickerCustomOption(id: "custom", title: "Custom Fetish")]
                ) { choice in
                    switch choice {
                    case .entry(let id):
                        character.fetishes.append(OwnedFetish(source: .catalog(id)))
                    case .custom:
                        addsCustomOnDismiss = true
                    }
                }
            }
        }
        .hostedSheet(isPresented: Binding(get: { shownFetish != nil }, set: { if !$0 { shownFetish = nil } })) {
            if let fetish = shownFetish {
                CatalogDetailView(title: fetish.name, summary: fetish.summary, citation: fetish.source.citation(), facts: [
                    DetailFact(label: fetish.kind == .talen ? "Talen" : "Fetish", value: String(repeating: "●", count: fetish.rating)),
                ] + [fetish.activation.map { DetailFact(label: "Activation", value: $0) },
                     fetish.effect.map { DetailFact(label: "Effect", value: $0) }].compactMap { $0 })
            }
        }
    }

    @ViewBuilder
    private func row(for fetish: OwnedFetish) -> some View {
        let entry = fetish.source.catalogID.flatMap { Catalog.bundled.fetishes.entry($0) }
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if let entry {
                    Button {
                        shownFetish = entry
                    } label: {
                        Text(entry.name)
                            .themedText(.traitName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows its details")
                } else {
                    TapToEditText(placeholder: "Fetish Name", text: Binding(
                        get: { if case .custom(let name) = fetish.source { name } else { "" } },
                        set: { fetish.source = .custom($0) }
                    ), beginsEditing: fetish.id == newCustomFetishID) { name in
                        Text(name).themedText(.traitName)
                    }
                }
                Spacer()
                if let entry {
                    DotsRatingView(entry.name, value: entry.rating, maxRating: 5)
                } else {
                    DotsRatingView("Fetish", rating: Binding(get: { fetish.customRating }, set: { fetish.customRating = max($0, 1) }),
                                   maxRating: 5)
                }
            }
            // e.g. the bound spirit, or a talen's uses left
            TapToEditText("Add a note", accessibilityName: "Note", text: Binding(get: { fetish.note }, set: { fetish.note = $0 }),
                          font: .detail)
        }
        .padding(.vertical, 4)
    }

    private func addCustomIfChosen() {
        guard addsCustomOnDismiss else { return }
        addsCustomOnDismiss = false
        let fetish = OwnedFetish(source: .custom(""))
        newCustomFetishID = fetish.id
        character.fetishes.append(fetish)
    }
}

// MARK: - Primal Urge and Essence

struct PrimalUrgeView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter

    var body: some View {
        SheetSectionBlock(.primalUrge) {
            VStack(alignment: .leading, spacing: 6) {
                DotsRatingView(
                    "Primal Urge",
                    rating: Binding(get: { character.primalUrge }, set: { character.primalUrge = max($0, 1) }),
                    maxRating: 10,
                    minEditableRating: 1,
                    dotsPerRow: 10
                )
                let level = character.primalUrgeLevel
                // The table's feeding restriction: what the werewolf can live on, from Primal Urge 2 (p. 93)
                let feeding = level.feeding == "None" ? nil : "Lives only on \(level.feeding.lowercased())"
                let lunacy = level.lunacyPenalty != 0 ? "Lunacy \(level.lunacyPenalty)" : nil
                Text((["Traits up to \(level.traitMaximum)", "Heals \(level.regeneration) bashing a turn"] + [feeding, lunacy].compactMap { $0 })
                    .joined(separator: " · "))
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 4)

            let level = character.primalUrgeLevel
            CounterRow("Essence:", value: Binding(get: { character.essence }, set: { character.essence = $0 }),
                       in: 0...level.essenceMaximum)
            Text("Holds \(level.essenceMaximum) · Spend up to \(level.essencePerTurn) a turn")
                .themedText(.detail)
                .foregroundStyle(theme.muted)
        }
    }
}

// MARK: - Harmony and Touchstones

struct HarmonyView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter

    var body: some View {
        SheetSectionBlock(.harmony) {
            VStack(alignment: .leading, spacing: 6) {
                DotsRatingView(
                    "Harmony",
                    rating: $character.harmony,
                    maxRating: 10,
                    dotsPerRow: 10,
                    allowsResetToZero: true
                )
                Text(levelText)
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 4)

            // The flesh Touchstone falls away at Harmony 2 or less, the spirit one at 8 or more (p. 87)
            CharacterInfoRowView(label: "Flesh:", text: $character.fleshTouchstone)
                .opacity(character.harmony <= 2 ? 0.5 : 1)
            CharacterInfoRowView(label: "Spirit:", text: $character.spiritTouchstone)
                .opacity(character.harmony >= 8 ? 0.5 : 1)
        }
    }

    /// The Harmony table (p. 105): bans, the Kuruth triggers that apply, and how long the character keeps control.
    private var levelText: String {
        let rows: [Int: (bans: Int, trigger: String?, control: String)] = [
            10: (0, "Passive", "3 seconds"), 9: (0, "Common", "10 seconds"), 8: (0, "Common", "30 seconds"),
            7: (0, "Specific", "1 minute"), 6: (0, "Specific", "5 minutes"), 5: (0, nil, "15 minutes"),
            4: (1, "Specific", "5 minutes"), 3: (1, "Specific", "1 minute"), 2: (2, "Common", "30 seconds"),
            1: (3, "Common", "10 seconds"), 0: (4, "Passive", "3 seconds"),
        ]
        guard let row = rows[min(max(character.harmony, 0), 10)] else { return "" }
        var parts = [row.trigger.map { "\($0) Kuruth triggers" } ?? "No Kuruth triggers", "Control for \(row.control)"]
        if row.bans > 0 {
            parts.append("\(row.bans) \(row.bans == 1 ? "ban" : "bans")")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Kuruth

struct KuruthView: View {
    @Bindable var character: ForsakenCharacter

    var body: some View {
        SheetSectionBlock(.kuruth) {
            CharacterInfoRowView(label: "Passive:", text: $character.kuruthTriggers.passive)
            CharacterInfoRowView(label: "Common:", text: $character.kuruthTriggers.common)
            CharacterInfoRowView(label: "Specific:", text: $character.kuruthTriggers.specific)
        }
    }
}
