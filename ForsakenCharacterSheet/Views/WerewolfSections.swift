//
//  WerewolfSections.swift
//  ForsakenCharacterSheet
//
//  The sections only a Forsaken sheet has: the character's auspice, tribe and lodge, form, Renown, Gifts, Rites,
//  fetishes, Primal Urge and Essence, Harmony and Touchstones, and Kuruth triggers.
//

import SwiftUI

extension SheetSection {
    static let creation = SheetSection("creation", title: "Creation", heading: "Character Creation")
    static let form = SheetSection("form", title: "Form")
    static let renown = SheetSection("renown", title: "Renown")
    static let auspiceBenefit = SheetSection("auspiceBenefit", title: "Auspice Benefit")
    static let lodge = SheetSection("lodge", title: "Lodge")
    static let moonGifts = SheetSection("moonGifts", title: "Moon Gifts")
    static let shadowGifts = SheetSection("shadowGifts", title: "Shadow Gifts")
    static let wolfGifts = SheetSection("wolfGifts", title: "Wolf Gifts")
    static let rites = SheetSection("rites", title: "Rites")
    static let totem = SheetSection("totem", title: "Totem")
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
                                             details: (limits.isEmpty ? [] : ["\(limits.joined(separator: ", ")) only"])
                                                 + lodge.marks.map { "\($0.label): \($0.value)" },
                                             citation: lodge.source.citation())
                }
            },
            customTitle: "Custom Lodge",
            noneTitle: "No Lodge",
            detail: {
                character.lodgeSource.catalogID.flatMap { catalog.entry($0) }.map {
                    CatalogChoiceDetail(title: $0.name, summary: $0.summary, citation: $0.source.citation(),
                                        facts: ($0.totem.map { [DetailFact(label: "Totem", value: $0)] } ?? []) + $0.marks)
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
                // With Favored Form's dots, if the character has it
                let changes = AttributeKind.allCases.compactMap { kind -> String? in
                    let change = character.formModifier(to: kind, in: form)
                    guard change != 0 else { return nil }
                    return "\(kind.name) \(change > 0 ? "+" : "−")\(abs(change))"
                }
                // Size, Speed and Perception are in Advantages, below
                Text(changes.joined(separator: " · "))
                    .themedText(.detail)
                Text(form.notes)
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)

            if let favored = character.favoredForm {
                FavoredFormView(character: character, form: favored.form, dots: favored.dots)
            }
        }
    }
}

/// What the Favored Form Merit raises in its form and lowers in the others (p. 106), chosen here so the Attributes
/// and everything worked out from them follow.
private struct FavoredFormView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter
    let form: Form
    let dots: Int

    var body: some View {
        Text("Favored Form: \(form.name)")
            .themedText(.subsectionHeader)
            .accessibilityAddTraits(.isHeader)
        if dots >= 2 {
            raisedRow("Second dot adds:", index: 0)
        }
        if dots >= 4 {
            raisedRow("Fourth dot adds:", index: 1)
        }
        ForEach(0..<dots, id: \.self) { index in
            HStack {
                Text(dots == 1 ? "Drawback:" : "Drawback \(index + 1):")
                    .themedText(.label)
                Spacer()
                Picker("Form", selection: drawback(index).form) {
                    Text("Form").tag(Form?.none)
                    ForEach(Form.allCases.filter { $0 != form }) { other in
                        Text(other.name).tag(Form?.some(other))
                    }
                }
                Picker("Attribute", selection: drawback(index).attribute) {
                    Text("Attribute").tag(AttributeKind?.none)
                    ForEach(FavoredFormChoices.drawbackAttributes, id: \.self) { kind in
                        Text("−1 \(kind.name)").tag(AttributeKind?.some(kind))
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(theme.accent)
        }
        Text("Each dot of the Merit takes a Mental or Physical Attribute dot from another form. Its first, third and fifth dots (a Skill, a Facet and a Skill in \(form.name)) aren't counted on the sheet.")
            .themedText(.detail)
            .foregroundStyle(theme.muted)
    }

    /// The Attribute a dot of the Merit raises in the favored form: any the form doesn't lower, and not the other
    /// dot's.
    private func raisedRow(_ label: String, index: Int) -> some View {
        let other = raised(1 - index).wrappedValue
        return HStack {
            Text(label)
                .themedText(.label)
            Spacer()
            Picker(label, selection: raised(index)) {
                Text("Attribute").tag(AttributeKind?.none)
                ForEach(FavoredFormChoices.attributes(raisedIn: form).filter { $0 != other }, id: \.self) { kind in
                    Text("+1 \(kind.name)").tag(AttributeKind?.some(kind))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(theme.accent)
        }
    }

    private func raised(_ index: Int) -> Binding<AttributeKind?> {
        Binding(
            get: {
                let attributes = character.favoredFormChoices.attributes
                return attributes.indices.contains(index) ? attributes[index] : nil
            },
            set: { kind in
                var attributes = character.favoredFormChoices.attributes
                while attributes.count <= index { attributes.append(nil) }
                attributes[index] = kind
                character.favoredFormChoices.attributes = attributes
            }
        )
    }

    private func drawback(_ index: Int) -> Binding<FavoredFormChoices.Drawback> {
        Binding(
            get: {
                let drawbacks = character.favoredFormChoices.drawbacks
                return drawbacks.indices.contains(index) ? drawbacks[index] : FavoredFormChoices.Drawback()
            },
            set: { drawback in
                var drawbacks = character.favoredFormChoices.drawbacks
                while drawbacks.count <= index { drawbacks.append(FavoredFormChoices.Drawback()) }
                drawbacks[index] = drawback
                character.favoredFormChoices.drawbacks = drawbacks
            }
        )
    }
}

// MARK: - Advantages

/// Size, Defense, Initiative, Speed and Perception in every form, as on the official sheet, with the current form
/// marked, and Armor.
struct AdvantagesView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter
    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = 82

    var body: some View {
        SheetSectionBlock(.advantages) {
            VStack(spacing: 6) {
                HStack(spacing: 2) {
                    Color.clear.frame(width: labelWidth, height: 1)
                    ForEach(Form.allCases) { form in
                        Text(form.name)
                            .themedText(.detail)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(form == character.form ? Color.white : theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(form == character.form ? theme.accent : Color.clear, in: Capsule())
                    }
                }
                // Five names in a row stay legible only up to a point; larger text goes to the numbers
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                traitRow("Size") { character.size(in: $0) }
                traitRow("Defense") { character.defense(in: $0) }
                ForEach(character.alternativeDefenseSkills, id: \.self) { skill in
                    traitRow("Def. (\(SkillDefinition.withID(skill)?.name ?? skill.rawValue))") { character.defense(in: $0, using: skill) }
                }
                traitRow("Initiative") { character.initiative(in: $0) }
                traitRow("Speed") { character.speed(in: $0) }
                traitRow("Perception", sign: true) { $0.perceptionBonus }
                textRow("Armor") { form in
                    let armor = character.armor(in: form)
                    return "\(armor.general)/\(armor.ballistic)"
                }
                Divider()
                traitRow("Brawl") { character.brawlPool(in: $0) }
                // Weapons and guns need hands, so only in Hishu and Dalu, and only for a character trained in them
                if character.rating(of: .weaponry) > 0 {
                    textRow("Weaponry") { character.weaponryPool(in: $0).map(String.init) ?? "—" }
                }
                if character.rating(of: .firearms) > 0 {
                    textRow("Firearms") { character.firearmsPool(in: $0).map(String.init) ?? "—" }
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Traits in \(character.form.name)")
            .accessibilityValue(summary(for: character.form))

            Text(notes)
                .themedText(.detail)
                .foregroundStyle(theme.muted)

            TapToEditNumberRow("Armor:", value: $character.armor, in: 0...99)
            TapToEditNumberRow("Ballistic Armor:", value: $character.ballisticArmor, in: 0...99)
        }
    }

    private func traitRow(_ label: String, sign: Bool = false, value: @escaping (Form) -> Int) -> some View {
        HStack(spacing: 2) {
            // A set width, shrinking a long label, so the five forms always fit beside it
            Text(label)
                .themedText(.label)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: labelWidth, alignment: .leading)
            ForEach(Form.allCases) { form in
                let number = value(form)
                Text(sign ? "+\(number)" : "\(number)")
                    .themedText(form == character.form ? .ratedTrait : .body)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func textRow(_ label: String, value: @escaping (Form) -> String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .themedText(.label)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: labelWidth, alignment: .leading)
            ForEach(Form.allCases) { form in
                Text(value(form))
                    .themedText(form == character.form ? .ratedTrait : .body)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func summary(for form: Form) -> String {
        "Size \(character.size(in: form)), Defense \(character.defense(in: form)), Initiative \(character.initiative(in: form)), "
            + "Speed \(character.speed(in: form)), Perception plus \(form.perceptionBonus), "
            + "Armor \(character.armor(in: form).general) general, \(character.armor(in: form).ballistic) ballistic, "
            + "Brawl pool \(character.brawlPool(in: form))"
    }

    /// What the numbers don't show (pp. 96–97). Hishu and Urhan don't apply Defense against Firearms (p. 166).
    private var notes: String {
        var notes = ["Perception is the bonus to rolls using wolf senses."]
        if character.form != .hishu && character.form != .urhan {
            notes.append("Defense applies against Firearms in \(character.form.name).")
        }
        if character.form == .gauru {
            notes.append("Initiative +3 when attacking with teeth or claws.")
        }
        // The Pure have a worse reaction to silver than the Forsaken (p. 198)
        if character.isPure {
            notes.append("Touching silver does 1 bashing damage a turn, or 1 lethal on nights of the full moon.")
        }
        return notes.joined(separator: " ")
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
                        // A dot gained in play brings a Facet (p. 115), learned in Shadow Gifts or Wolf Gifts
                        if character.renownsWithFreeFacets.contains(kind) {
                            let count = character.renownFacetCredits[kind] ?? 0
                            Text(count == 1 ? "A free Facet to learn" : "\(count) free Facets to learn")
                                .themedText(.detail)
                                .foregroundStyle(theme.accent)
                        }
                    }
                    Spacer()
                    DotsRatingView(
                        kind.name,
                        rating: Binding(get: { character.renown(kind) }, set: { character.setRenown(kind, to: $0) }),
                        maxRating: 5,
                        maxEditableRating: character.editableMaximum(for: TraitKey(.renown, kind.rawValue), upTo: 5),
                        minEditableRating: character.grantedRenownDots(kind),
                        allowsResetToZero: true
                    )
                }
                .padding(.vertical, 4)
            }
            // What spirits take the character for, from all their Renown (p. 99)
            LabeledValueRow("Spirit Rank:", value: character.spiritRank)
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

// MARK: - Auspice Benefit

/// The power the character's auspice gives them, shown where it won't be forgotten.
struct AuspiceBenefitView: View {
    @Environment(\.theme) private var theme
    let benefit: AuspiceEntry.Benefit
    let auspice: AuspiceEntry

    var body: some View {
        SheetSectionBlock(.auspiceBenefit) {
            VStack(alignment: .leading, spacing: 6) {
                Text(benefit.name)
                    .themedText(.traitName)
                Text(benefit.summary)
                    .themedText(.body)
                Text(SourceReference(book: auspice.source.book, page: benefit.page ?? auspice.source.page).citation())
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Lodge

extension LodgeEntry {
    /// What the lodge gives every adherent: its benefit, or the three marks of its totem bond (The Pack, p. 80).
    var marks: [DetailFact] {
        [benefit.map { DetailFact(label: "Benefit", value: $0) },
         blessing.map { DetailFact(label: "Blessing", value: $0) },
         aspiration.map { DetailFact(label: "Aspiration", value: $0) },
         ban.map { DetailFact(label: "Ban", value: $0) }].compactMap { $0 }
    }

    /// The benefit the lodge's ritemaster can give the Sacred Hunt in place of their tribe's.
    var sacredHunt: ConditionNoteOption? {
        Catalog.bundled.conditions.entry("siskur-dah")?.noteOptions.first { $0.group == "lodge" && $0.id == id }
    }

    /// What the lodge teaches, by name, e.g. "Lodge Armory, Uma Suguthkuth, Predator's Doom".
    var lore: [String] {
        let catalog = Catalog.bundled
        return (merits ?? []).compactMap { catalog.merits.entry($0)?.name }
            + (rites ?? []).compactMap { catalog.rites.entry($0)?.name }
            + (fetishes ?? []).compactMap { catalog.fetishes.entry($0)?.name }
    }
}

/// What a lodge with rules gives its adherent, kept in view like the auspice's benefit: the Blessing, the extra
/// Aspiration and the Ban, its Sacred Hunt and what it teaches.
struct LodgeView: View {
    @Environment(\.theme) private var theme
    let lodge: LodgeEntry

    var body: some View {
        SheetSectionBlock(.lodge) {
            VStack(alignment: .leading, spacing: 6) {
                Text(lodge.name)
                    .themedText(.traitName)
                ForEach(lodge.marks + facts) { fact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label)
                            .themedText(.subsectionHeader)
                        Text(fact.value)
                            .themedText(.body)
                    }
                    .accessibilityElement(children: .combine)
                }
                if lodge.ban != nil {
                    Text("Breaking the ban brings the Ban Condition; breaking it again under that Condition takes the Blessing away while it lasts. Lodge lore costs a werewolf outside the lodge three times the Experiences.")
                        .themedText(.detail)
                        .foregroundStyle(theme.muted)
                }
                Text(lodge.source.citation())
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 4)
        }
    }

    private var facts: [DetailFact] {
        let lore = lodge.lore.isEmpty ? nil : lodge.lore.listed("and") + "."
        return [lodge.sacredHunt.map { DetailFact(label: "Sacred Hunt", value: $0.summary) },
                [lore, lodge.tools].compactMap { $0 }.isEmpty ? nil
                    : DetailFact(label: "Lodge Lore", value: [lore, lodge.tools].compactMap { $0 }.joined(separator: " "))]
            .compactMap { $0 }
    }
}

// MARK: - Gifts

extension FacetPrice {
    /// e.g. "Costs 3 Experiences, and unlocks the Gift".
    var text: String {
        switch self {
        case .renown(let renown):
            "Free with your new dot of \(renown.name)"
        case .experiences(let cost, let unlocksGift):
            "Costs \(cost) \(cost == 1 ? "Experience" : "Experiences")" + (unlocksGift ? ", and unlocks the Gift" : "")
        }
    }
}

/// A Facet as a row to scan at the table: its name, what it takes to use, and its dice pool worked out for the
/// character in the form they're in.
private struct FacetSummary: View {
    @Environment(\.theme) private var theme
    let character: ForsakenCharacter
    let facet: GiftEntry.Facet
    /// Said after the Facet's own facts, e.g. "Learned with Renown".
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(facet.name)
                .themedText(.traitName)
            if !facts.isEmpty {
                Text(facts.joined(separator: " · "))
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            if let pool = facet.dicePool {
                poolText(pool)
                    .themedText(.detail)
            }
            PowerEffectNote(facet: facet)
        }
    }

    /// e.g. "Cunning · 1 Essence · Contested · 1 scene".
    private var facts: [String] {
        [facet.renown?.name, facet.cost.map { $0 == "None" ? "No cost" : $0 }, facet.action?.capitalizedFirst, facet.duration, note]
            .compactMap { $0 }
    }

    /// The pool with its dice counted, e.g. "7 dice · Wits + Occult + Wisdom vs Resistance", or as the book
    /// writes it if it isn't made of the sheet's traits.
    private func poolText(_ pool: String) -> Text {
        guard let worked = character.worked(pool, in: character.form) else { return Text(pool) }
        let traits = worked.against.isEmpty ? worked.traits : "\(worked.traits) \(worked.against)"
        return Text("\(Text(worked.diceText).bold().foregroundStyle(theme.accent)) · \(traits)")
    }
}

extension WorkedDicePool {
    /// e.g. "7 dice", or "Chance die" for a pool of none.
    var diceText: String {
        dice < 1 ? "Chance die" : dice == 1 ? "1 die" : "\(dice) dice"
    }
}

private extension String {
    /// With its first letter a capital, e.g. "Instant, may be contested".
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

/// The Moon Gift the character's auspice gives, whose Facets come one for each dot of auspice Renown, and any other
/// Moon Gifts unlocked with Experiences.
struct MoonGiftView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter
    @State private var shownFacet: (gift: GiftEntry, facet: GiftEntry.Facet)?
    @State private var showingPicker = false
    /// A custom Moon Gift that was just added, whose name opens for editing.
    @State private var newCustomGiftID: UUID?
    @State private var addsCustomOnDismiss = false

    var body: some View {
        SheetSectionBlock(.moonGifts) {
            moonGiftRow
            if let gift = character.moonGift {
                facetRows(of: gift, known: character.moonGiftDots) { dots in
                    character.moonGiftRenown.map { "Comes with \($0.name) \(dots)" }
                }
            } else if case .custom = character.moonGiftSource {
                customFacetRows(id: "moon-facet", known: character.moonGiftDots,
                                names: Binding(get: { character.customMoonFacets }, set: { character.customMoonFacets = $0 }))
            }

            ForEach(character.extraMoonGifts) { owned in
                extraGiftRow(owned)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            character.extraMoonGifts.removeAll { $0.id == owned.id }
                        }
                    }
                if let gift = character.gift(of: owned) {
                    facetRows(of: gift, known: character.dots(of: owned)) { _ in nil }
                } else {
                    customFacetRows(id: "moon-facet-\(owned.id)", known: character.dots(of: owned),
                                    names: Binding(get: { owned.customFacets }, set: { owned.customFacets = $0 }))
                }
            }

            // Another Moon Gift is found in play, never at creation (p. 114)
            if !character.isInCreation {
                AddRowButton("Add Moon Gift") {
                    showingPicker = true
                }
                .hostedSheet(isPresented: $showingPicker, onDismiss: addCustomIfChosen) {
                    addPicker
                }
            }
        }
        .hostedSheet(isPresented: Binding(get: { shownFacet != nil }, set: { if !$0 { shownFacet = nil } })) {
            if let shownFacet {
                CatalogDetailView(title: shownFacet.facet.name, summary: shownFacet.facet.summary,
                                  citation: shownFacet.facet.source.citation(),
                                  facts: facetFacts(shownFacet.gift, shownFacet.facet, for: character))
            }
        }
    }

    /// A catalog Moon Gift's Facets in order: those the character has, to scan and to open, then the rest muted.
    private func facetRows(of gift: GiftEntry, known: Int, lockedNote: @escaping (Int) -> String?) -> some View {
        ForEach(gift.facets.sorted { ($0.dots ?? 0) < ($1.dots ?? 0) }) { facet in
            let dots = facet.dots ?? 0
            Button {
                shownFacet = (gift, facet)
            } label: {
                facetLabel(dots: dots, unlocked: dots <= known) {
                    if dots <= known {
                        FacetSummary(character: character, facet: facet)
                    } else {
                        lockedName(Text(facet.name), note: lockedNote(dots))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows its details")
        }
    }

    /// A custom Moon Gift's five Facets, named by the player.
    private func customFacetRows(id: String, known: Int, names: Binding<[String]>) -> some View {
        ForEach(1...5, id: \.self) { dots in
            facetLabel(dots: dots, unlocked: dots <= known) {
                TapToEditText("Facet Name", accessibilityName: "\(dots)-dot Facet", text: Binding(
                    get: { names.wrappedValue.indices.contains(dots - 1) ? names.wrappedValue[dots - 1] : "" },
                    set: { name in
                        var all = names.wrappedValue
                        while all.count < dots { all.append("") }
                        all[dots - 1] = name
                        // Trailing empty names aren't kept
                        while all.last?.isEmpty == true { all.removeLast() }
                        names.wrappedValue = all
                    }
                ), font: .traitName)
            }
            .editingRow("\(id)-\(dots)")
        }
    }

    private func lockedName(_ name: Text, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            name.themedText(.traitName)
            if let note {
                Text(note)
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
        }
    }

    /// A Facet beside its dots, muted until the character has it.
    private func facetLabel(dots: Int, unlocked: Bool, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline) {
            content()
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
        .accessibilityValue(unlocked ? "Known" : "Not known")
    }

    /// A Moon Gift bought with Experiences: its name, and how many of its Facets the character has. Each dot is the
    /// next Facet, so tapping them buys the Facets in order, as far as auspice Renown allows.
    private func extraGiftRow(_ owned: OwnedMoonGift) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if owned.source.catalogID != nil {
                    Text(character.moonGiftName(owned))
                        .themedText(.subsectionHeader)
                        .accessibilityAddTraits(.isHeader)
                } else {
                    TapToEditText(placeholder: "Moon Gift Name", text: Binding(
                        get: { character.moonGiftName(owned) }, set: { owned.source = .custom($0) }
                    ), beginsEditing: owned.id == newCustomGiftID) { name in
                        Text(name).themedText(.subsectionHeader)
                    }
                }
                Spacer()
                DotsRatingView(
                    character.moonGiftName(owned),
                    rating: Binding(get: { owned.dots }, set: { owned.dots = max($0, 1) }),
                    countedRating: character.dots(of: owned),
                    maxRating: 5,
                    maxEditableRating: max(character.moonGiftDots, 1),
                    minEditableRating: 1
                )
            }
            if let note = nextFacetNote(owned) {
                Text(note)
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
        }
        .padding(.vertical, 4)
        .editingRow(owned.id)
    }

    /// What stands between the character and the Gift's next Facet: auspice Renown, or Experiences.
    private func nextFacetNote(_ owned: OwnedMoonGift) -> String? {
        guard owned.dots < 5, let renown = character.moonGiftRenown else { return nil }
        if owned.dots >= character.moonGiftDots {
            return "Its next Facet needs \(renown.name) \(owned.dots + 1)"
        }
        return character.xpMode ? "Its next Facet costs \(FacetPrice.furtherFacet) Experiences" : nil
    }

    private var moonGifts: [GiftEntry] {
        Catalog.bundled.gifts.all.filter { $0.kind == .moon }
    }

    /// The auspice's own Moon Gifts first, e.g. the core book's and any alternates, then the rest.
    private func moonGiftSections(item: (GiftEntry) -> CatalogPickerItem) -> [CatalogPickerSection] {
        let auspice = character.effectiveAuspice?.id
        return pickerSections([
            CatalogPickerGroup(auspice == nil ? "" : "Your Auspice", moonGifts.filter { $0.auspice == auspice }),
            CatalogPickerGroup(auspice == nil ? "" : "Other Auspices", moonGifts.filter { $0.auspice != auspice }),
        ], item: item)
    }

    private func auspiceName(of gift: GiftEntry) -> String? {
        gift.auspice.flatMap { Catalog.bundled.auspices.entry($0)?.name }
    }

    private var moonGiftRow: some View {
        let isCustom: Bool = if case .custom = character.moonGiftSource { true } else { false }
        return CatalogChoiceRow(
            label: "Moon Gift:",
            value: character.moonGiftName,
            isCustom: isCustom,
            setCustomText: { character.moonGiftSource = .custom($0) },
            pickerTitle: "Moon Gift",
            searchPrompt: "Search Moon Gifts",
            sections: {
                moonGiftSections { gift in
                    CatalogPickerItem(id: gift.id, name: gift.name, summary: gift.summary,
                                      details: auspiceName(of: gift).map { ["\($0) only"] } ?? [],
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

    /// The Moon Gifts the character could unlock with Experiences: any but the ones they have. Only their own
    /// auspice's are theirs to find (p. 114), so the others carry a warning.
    private var addPicker: some View {
        let owned = Set(character.extraMoonGifts.compactMap(\.source.catalogID) + [character.moonGift?.id].compactMap { $0 })
        let price = character.xpMode
            ? "Costs \(FacetPrice.otherGift) Experiences with its first Facet, then \(FacetPrice.furtherFacet) for each Facet after it" : nil
        return CatalogPickerView(
            title: "Add Moon Gift",
            searchPrompt: "Search Moon Gifts",
            sections: moonGiftSections { gift in
                let ownAuspice = gift.auspice == character.effectiveAuspice?.id
                let renown = character.moonGiftRenown
                return CatalogPickerItem(
                    id: gift.id, name: gift.name, summary: gift.summary, details: [price].compactMap { $0 },
                    warning: !ownAuspice ? auspiceName(of: gift).map { "A Moon Gift of the \($0)" }
                        : character.moonGiftDots == 0 ? renown.map { "Needs \($0.name) 1" } : nil,
                    citation: gift.source.citation(), isOwned: owned.contains(gift.id))
            },
            customOptions: [CatalogPickerCustomOption(id: "custom", title: "Custom Moon Gift")]
        ) { choice in
            switch choice {
            case .entry(let id):
                character.extraMoonGifts.append(OwnedMoonGift(source: .catalog(id)))
            case .custom:
                addsCustomOnDismiss = true
            }
        }
    }

    private func addCustomIfChosen() {
        guard addsCustomOnDismiss else { return }
        addsCustomOnDismiss = false
        let gift = OwnedMoonGift(source: .custom(""))
        newCustomGiftID = gift.id
        character.extraMoonGifts.append(gift)
    }
}

/// The Shadow or Wolf Gift Facets the character knows, and learning more.
struct GiftsView: View {
    /// What the picker offers: every Facet of this kind of Gift, or only those a new dot of Renown brings free.
    private enum Offer: Equatable {
        case all
        case free(Renown)
    }

    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter
    /// `.shadow` or `.wolf`.
    let kind: GiftEntry.Kind
    @State private var offer: Offer?
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

    /// The Facets by Gift, in the order the Gifts were first learned, e.g. Primal Allure and Snarl of the Predator
    /// together under the Gift of Dominance.
    private var facetsByGift: [(name: String, gift: GiftEntry?, facets: [OwnedFacet])] {
        var groups: [(key: String, name: String, gift: GiftEntry?, facets: [OwnedFacet])] = []
        for owned in facets {
            let gift = character.gift(of: owned)
            let key = gift?.id ?? "custom:" + owned.customGift
            let name = gift?.name ?? (owned.customGift.isEmpty ? "Custom Gift" : owned.customGift)
            if let index = groups.firstIndex(where: { $0.key == key }) {
                groups[index].facets.append(owned)
            } else {
                groups.append((key, name, gift, [owned]))
            }
        }
        return groups.map { ($0.name, $0.gift, $0.facets) }
    }

    var body: some View {
        SheetSectionBlock(kind == .wolf ? .wolfGifts : .shadowGifts) {
            ForEach(character.renownsWithFreeFacets) { renown in
                freeFacetRow(renown)
            }
            ForEach(facetsByGift, id: \.name) { group in
                HStack(alignment: .firstTextBaseline) {
                    Text(group.name)
                        .themedText(.subsectionHeader)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    // How much of the Gift is learned, e.g. "2 of 5"
                    if let gift = group.gift {
                        Text("\(group.facets.count) of \(gift.facets.count)")
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                            .accessibilityLabel("\(group.facets.count) of \(gift.facets.count) Facets")
                    }
                }
                ForEach(group.facets) { owned in
                    row(for: owned)
                        .editingRow(owned.id)
                }
                .onDelete { offsets in
                    offsets.map { group.facets[$0] }.forEach(character.forget)
                }
            }

            AddRowButton("Add \(kindName) Facet") {
                offer = .all
            }
            .hostedSheet(isPresented: Binding(get: { offer != nil }, set: { if !$0 { offer = nil } }), onDismiss: addCustomIfChosen) {
                if let offer {
                    picker(offer)
                }
            }
        }
        .hostedSheet(isPresented: Binding(get: { shownFacet != nil }, set: { if !$0 { shownFacet = nil } })) {
            if let shownFacet {
                CatalogDetailView(title: shownFacet.facet.name, summary: shownFacet.facet.summary,
                                  citation: shownFacet.facet.source.citation(),
                                  facts: facetFacts(shownFacet.gift, shownFacet.facet, for: character))
            }
        }
    }

    private func picker(_ offer: Offer) -> some View {
        let title = switch offer {
        case .all: "Add \(kindName) Facet"
        case .free(let renown): "Free \(renown.name) Facet"
        }
        return CatalogPickerView(
            title: title,
            searchPrompt: "Search \(kindName) Gifts and Facets",
            sections: facetSections(offer),
            customOptions: offer == .all ? [CatalogPickerCustomOption(id: "custom", title: "Custom \(kindName) Facet")] : []
        ) { choice in
            switch choice {
            case .entry(let id):
                if let found = Catalog.bundled.facet(id) {
                    character.learn(found.facet, of: found.gift)
                }
            case .custom:
                addsCustomOnDismiss = true
            }
        }
    }

    /// A free Facet a new dot of Renown has brought (p. 115), which opens the Facets it could be. With none of this
    /// kind to learn, it's left to the other kind of Gift; with none at all, it waits for a Gift that has one.
    @ViewBuilder
    private func freeFacetRow(_ renown: Renown) -> some View {
        let count = character.renownFacetCredits[renown] ?? 0
        let choices = character.freeFacetChoices(for: renown)
        if choices.contains(where: { $0.gift.kind == kind }) {
            Button {
                offer = .free(renown)
            } label: {
                Label(count == 1 ? "Learn a free \(renown.name) Facet, for your new dot of \(renown.name)"
                          : "Learn \(count) free \(renown.name) Facets, for your new dots of \(renown.name)",
                      systemImage: "sparkles")
                    .themedText(.body)
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the Facets you can learn free")
        } else if choices.isEmpty, kind == .shadow {
            Label("A free \(renown.name) Facet is waiting: you know every \(renown.name) Facet of your Gifts, so it's kept for the next Gift you unlock.",
                  systemImage: "sparkles")
                .themedText(.detail)
                .foregroundStyle(theme.accent)
        }
    }

    @ViewBuilder
    private func row(for owned: OwnedFacet) -> some View {
        if let id = owned.source.catalogID, let found = Catalog.bundled.facet(id) {
            Button {
                shownFacet = found
            } label: {
                FacetSummary(character: character, facet: found.facet, note: owned.learnedWithRenown ? "Learned with Renown" : nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows its details")
            .padding(.vertical, 4)
            // A power that changes the sheet while in use, e.g. Primal Strength, is switched on here
            if found.facet.effects?.isEmpty == false, found.facet.passive != true {
                PowerToggle(isOn: Binding(get: { owned.isActive }, set: { owned.isActive = $0 }), name: found.facet.name)
            }
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

    /// The Gifts by book, each a section: for Shadow Gifts, the tribe's and auspice's first, then the others. Only
    /// the Facets a new dot of Renown could bring, if that's what's offered.
    private func facetSections(_ offer: Offer) -> [CatalogPickerSection] {
        let gifts = Catalog.bundled.gifts.all.filter { $0.kind == kind }
        let ordered = gifts.filter { character.hasAffinity(for: $0) }
            + gifts.filter { !character.hasAffinity(for: $0) }
        let owned = Set(character.facets.compactMap(\.source.catalogID))
        // Costs are the sheet's to work out only in XP Mode, and creation's Facets are free
        let showsPrices = character.xpMode && !character.isInCreation
        return ordered.flatMap { gift in
            let facets = switch offer {
            case .all: gift.facets
            case .free(let renown): gift.facets.filter { $0.renown == renown && !owned.contains($0.id) && character.canLearnFree($0, of: gift) }
            }
            return pickerSections([CatalogPickerGroup(sectionTitle(gift), facets)]) { facet in
                CatalogPickerItem(
                    id: facet.id,
                    name: facet.name,
                    summary: facet.summary,
                    details: [[facet.renown?.name, facet.cost.map { $0 == "None" ? "No cost" : $0 }].compactMap { $0 }.joined(separator: " · "),
                              showsPrices && !owned.contains(facet.id) ? character.price(of: facet, in: gift).text : nil]
                        .compactMap { $0 }.filter { !$0.isEmpty },
                    warning: facet.renown.flatMap { character.renown($0) == 0 ? "Needs \($0.name) 1" : nil },
                    citation: facet.source.citation(),
                    isOwned: owned.contains(facet.id),
                    unavailableReason: creationReason(gift, facet)
                )
            }
        }
    }

    /// Why guided creation won't take the Facet, if it won't: the clearest reason first.
    private func creationReason(_ gift: GiftEntry, _ facet: GiftEntry.Facet) -> String? {
        guard !character.creationAllows(.facet(facet, gift: gift)) else { return nil }
        if let renown = facet.renown, character.renown(renown) == 0 {
            return "Needs a dot of \(renown.name) first"
        }
        if gift.kind == .shadow, !character.hasAffinity(for: gift) {
            return character.isPure ? "Only one Facet may be from outside your tribe's Gifts" : "Not one of your tribe's or auspice's Gifts"
        }
        if gift.kind == .shadow, !character.isPure, character.creationReport.shadowFacets.remaining > 0,
           character.facets.contains(where: { character.gift(of: $0)?.id == gift.id }) {
            return "Your two Shadow Facets come from two different Gifts"
        }
        return "No more \(kindName) Facets at creation"
    }

    private func sectionTitle(_ gift: GiftEntry) -> String {
        character.hasAffinity(for: gift) ? "\(gift.name) (Affinity)" : gift.name
    }

    private func addCustomIfChosen() {
        guard addsCustomOnDismiss else { return }
        addsCustomOnDismiss = false
        let facet = OwnedFacet(source: .custom(""), customKind: kind)
        newCustomFacetID = facet.id
        character.facets.append(facet)
    }
}

/// What a Facet always does to the sheet, e.g. "Always on: adds Purity to Health".
private struct PowerEffectNote: View {
    @Environment(\.theme) private var theme
    let facet: GiftEntry.Facet

    var body: some View {
        if facet.passive == true, facet.effects?.isEmpty == false {
            Text("Always on, and counted on the sheet")
                .themedText(.detail)
                .foregroundStyle(theme.accent)
        }
    }
}

/// Switches on a power while it's in use, so its dots show on the sheet and in dice pools.
struct PowerToggle: View {
    @Environment(\.theme) private var theme
    @Binding var isOn: Bool
    let name: String

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(isOn ? "In use, counted on the sheet" : "Not in use")
                .themedText(.detail)
                .foregroundStyle(isOn ? theme.accent : theme.muted)
        }
        .tint(theme.accent)
        .accessibilityLabel("\(name) in use")
    }
}

/// A Facet's details: its Gift, Renown or dots, cost, dice pool (with the character's dice in the form they're in),
/// action and duration.
@MainActor
private func facetFacts(_ gift: GiftEntry, _ facet: GiftEntry.Facet, for character: ForsakenCharacter) -> [DetailFact] {
    var facts = [DetailFact(label: "Gift", value: gift.name)]
    if let renown = facet.renown { facts.append(DetailFact(label: "Renown", value: renown.name)) }
    if let dots = facet.dots { facts.append(DetailFact(label: "Dots", value: String(repeating: "●", count: dots))) }
    if let cost = facet.cost { facts.append(DetailFact(label: "Cost", value: cost)) }
    if let pool = facet.dicePool {
        let worked = character.worked(pool, in: character.form).map { " (\($0.diceText) in \(character.form.name))" } ?? ""
        facts.append(DetailFact(label: "Dice Pool", value: pool + worked))
    }
    if let action = facet.action { facts.append(DetailFact(label: "Action", value: action.capitalized)) }
    if let duration = facet.duration { facts.append(DetailFact(label: "Duration", value: duration)) }
    return facts
}

// MARK: - Totem

/// The pack's totem: its name, Aspiration and ban, the pack's Totem points, and the advantages they buy, which every
/// pack member gains and which may break the usual rules (pp. 92–93).
struct TotemView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter
    @State private var showingMeritPicker = false
    @State private var specialtySkill: SkillDefinition?
    @State private var specialtyDraft = ""

    private var ownDots: Int {
        character.merits.first { $0.source == .catalog("totem") }?.rating ?? 0
    }

    var body: some View {
        SheetSectionBlock(.totem) {
            CharacterInfoRowView(label: "Name:", text: $character.totem.name, rowID: "totem-name")
            CharacterInfoRowView(label: "Aspiration:", text: $character.totem.aspiration, rowID: "totem-aspiration")
            CharacterInfoRowView(label: "Ban:", text: $character.totem.ban, rowID: "totem-ban")
            VStack(alignment: .leading, spacing: 2) {
                CounterRow("Pack's Totem points:", value: $character.totem.packPoints, in: 0...99)
                Text("Every packmate's Totem dots added up. Yours: \(ownDots), from the Totem Merit.")
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }

            VStack(alignment: .leading, spacing: 2) {
                let totem = character.totem
                // The colour goes inside the theme style, whose own colour would otherwise win
                Text("Advantages: \(totem.experiencesSpent) of \(totem.experienceBudget) Experiences")
                    .foregroundStyle(totem.experiencesSpent > totem.experienceBudget ? theme.caution : theme.accent)
                    .themedText(.label)
                Text("Every pack member gains them, even past their usual limits or without a Merit's prerequisites.")
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 4)

            ForEach($character.totem.advantages) { $advantage in
                advantageRow($advantage)
            }
            .onDelete { character.totem.advantages.remove(atOffsets: $0) }

            addMenu
        }
        // A granted Merit gets a row in Merits, where its dots join any the character buys
        .onChange(of: character.totem.advantages) { old, _ in character.syncTotemMerits(previous: old) }
        .hostedSheet(isPresented: $showingMeritPicker) {
            MeritPickerView(character: character, grantsAdvantage: true, excluding: Totem.meritsNeverGranted) { entry, qualifier in
                guard let entry else { return }
                character.totem.advantages.append(TotemAdvantage(kind: .merit, target: entry.id, detail: qualifier ?? "",
                                                                 dots: entry.ratings.min() ?? 1))
            }
        }
        .alert("Totem Specialty", isPresented: Binding(get: { specialtySkill != nil }, set: { if !$0 { specialtySkill = nil } }),
               presenting: specialtySkill) { skill in
            TextField("Specialty", text: $specialtyDraft)
            Button("Add") {
                let name = specialtyDraft.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    character.totem.advantages.append(TotemAdvantage(kind: .specialty, target: skill.id.rawValue, detail: name))
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { skill in
            Text(skill.name)
        }
    }

    private var addMenu: some View {
        Menu {
            Menu("Attribute") {
                ForEach(TraitCategory.allCases, id: \.self) { category in
                    Section(category.name) {
                        ForEach(AttributeKind.allCases.filter { $0.category == category }, id: \.self) { kind in
                            Button(kind.name) { add(.attribute, kind.rawValue) }
                        }
                    }
                }
            }
            // A menu for each category, so none is too long to fit
            Menu("Skill") { skillMenus { add(.skill, $0.id.rawValue) } }
            Menu("Skill Specialty") {
                skillMenus { skill in
                    specialtyDraft = ""
                    specialtySkill = skill
                }
            }
            Button("Merit") { showingMeritPicker = true }
        } label: {
            Label("Add Advantage", systemImage: "plus.circle")
                .themedText(.body)
                .foregroundStyle(theme.accent)
        }
    }

    private func skillMenus(_ choose: @escaping (SkillDefinition) -> Void) -> some View {
        ForEach(TraitCategory.allCases, id: \.self) { category in
            Menu(category.name) {
                ForEach(character.skills(in: category).compactMap { SkillDefinition.withID($0.skillID) }) { skill in
                    Button(skill.name) { choose(skill) }
                }
            }
        }
    }

    private func add(_ kind: TotemAdvantage.Kind, _ target: String) {
        // Another dot of something already granted goes on the same line
        if let index = character.totem.advantages.firstIndex(where: { $0.kind == kind && $0.target == target }) {
            character.totem.advantages[index].dots += 1
        } else {
            character.totem.advantages.append(TotemAdvantage(kind: kind, target: target))
        }
    }

    private func advantageRow(_ advantage: Binding<TotemAdvantage>) -> some View {
        let value = advantage.wrappedValue
        let costText = "\(value.cost) \(value.cost == 1 ? "Experience" : "Experiences")"
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name(of: value))
                    .themedText(.traitName)
                Text(costText)
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            Spacer()
            if value.kind != .specialty {
                Stepper("Dots", value: advantage.dots, in: dotRange(value))
                    .labelsHidden()
                // A set width, so the steppers line up from row to row
                Text(String(repeating: "●", count: value.dots))
                    .foregroundStyle(theme.ink)
                    .frame(width: 64, alignment: .leading)
                    .accessibilityLabel(value.dots == 1 ? "1 dot" : "\(value.dots) dots")
            }
        }
        .padding(.vertical, 4)
    }

    private func dotRange(_ advantage: TotemAdvantage) -> ClosedRange<Int> {
        guard advantage.kind == .merit, let ratings = Catalog.bundled.merits.entry(advantage.target)?.ratings,
              let low = ratings.min(), let high = ratings.max() else { return 1...5 }
        return low...high
    }

    private func name(of advantage: TotemAdvantage) -> String {
        switch advantage.kind {
        case .attribute:
            return AttributeKind(rawValue: advantage.target)?.name ?? advantage.target
        case .skill:
            return SkillDefinition.withID(SkillID(rawValue: advantage.target))?.name ?? advantage.target
        case .specialty:
            let skill = SkillDefinition.withID(SkillID(rawValue: advantage.target))?.name ?? advantage.target
            return "\(skill) (\(advantage.detail))"
        case .merit:
            let merit = Catalog.bundled.merits.entry(advantage.target)?.name ?? advantage.target
            return advantage.detail.isEmpty ? merit : "\(merit) (\(advantage.detail))"
        }
    }
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
                        let lodges = Catalog.bundled.lodges(teachingRite: rite.id)
                        return CatalogPickerItem(id: rite.id, name: rite.name, dots: rite.rating, summary: rite.summary,
                                          details: rite.targetSuccesses.map { ["\($0) successes"] } ?? [],
                                          warning: lodges.isEmpty || character.isAdherent(ofAny: lodges) ? nil
                                              : "Requires \(ForsakenCharacter.lodgeRequirement(lodges)) (three times the cost otherwise)",
                                          citation: rite.source.citation(), isOwned: owned.contains(rite.id),
                                          unavailableReason: character.creationAllows(.rite(dots: rite.rating))
                                              ? nil : "Doesn't fit the starting Rites and Merit dots")
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
                ] + [rite.symbols.map { DetailFact(label: "Symbols", value: $0) },
                     rite.dicePool.map { DetailFact(label: "Sample Pool", value: $0) },
                     rite.targetSuccesses.map { DetailFact(label: "Target", value: "\($0) successes") },
                     rite.interval.map { DetailFact(label: "Each Roll", value: $0) },
                     rite.cost.map { DetailFact(label: "Cost", value: $0) },
                     rite.duration.map { DetailFact(label: "Duration", value: $0) },
                     lodgeFact(for: rite)].compactMap { $0 })
            }
        }
    }

    /// e.g. "Lodge of the Screaming Moon", for a rite a lodge teaches.
    private func lodgeFact(for rite: RiteEntry) -> DetailFact? {
        let lodges = Catalog.bundled.lodges(teachingRite: rite.id)
        return lodges.isEmpty ? nil : DetailFact(label: "Lodge", value: lodges.map(\.name).listed("or")
            + ". A werewolf outside it pays three times the Experiences.")
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
                    // Only the rite's own dots, like a Merit with one rating, in the five-dot column
                    DotsRatingView(entry.name, value: entry.rating, maxRating: entry.rating)
                        .frame(width: DotsRatingView.width(forDots: 5), alignment: .leading)
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
            if entry.effects?.isEmpty == false {
                PowerToggle(isOn: Binding(get: { rite.isActive }, set: { rite.isActive = $0 }), name: entry.name)
            }
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
                    // Only the rite's own dots, like a Merit with one rating, in the five-dot column
                    DotsRatingView(entry.name, value: entry.rating, maxRating: entry.rating)
                        .frame(width: DotsRatingView.width(forDots: 5), alignment: .leading)
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
                    maxEditableRating: character.editableMaximum(for: TraitKey(.primalUrge, "primalUrge"), upTo: 10),
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
                       in: 0...character.essenceMaximum)
            Text("Holds \(character.essenceMaximum) · Spend up to \(level.essencePerTurn) a turn")
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
                    // Every werewolf starts at 7
                    isInteractive: !character.isInCreation,
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

/// The character's set of Kuruth triggers, muted where their Harmony means they don't apply, and the triggers every
/// werewolf has.
struct KuruthView: View {
    @Environment(\.theme) private var theme
    @Bindable var character: ForsakenCharacter

    var body: some View {
        SheetSectionBlock(.kuruth) {
            triggerSetRow
            ForEach(KuruthTriggers.Kind.allCases) { kind in
                triggerRow(kind)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("General Triggers")
                    .themedText(.subsectionHeader)
                    .accessibilityAddTraits(.isHeader)
                ForEach(KuruthTriggers.general, id: \.self) { trigger in
                    Text("• \(trigger)")
                        .themedText(.body)
                }
                Text("They apply at any Harmony, as often as they happen; personal triggers only once a night.")
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 4)
        }
    }

    private var triggerSetRow: some View {
        let catalog = Catalog.bundled.kuruthTriggers
        return CatalogChoiceRow(
            label: "Trigger Set:",
            value: catalog.name(of: character.kuruthTriggerSource),
            isCustom: character.kuruthTriggerSource.catalogID == nil,
            setCustomText: { character.kuruthTriggerSource = .custom($0) },
            pickerTitle: "Kuruth Triggers",
            searchPrompt: "Search trigger sets",
            sections: {
                pickerSections([CatalogPickerGroup("", catalog.all)]) { set in
                    CatalogPickerItem(id: set.id, name: set.name, summary: set.summary,
                                      details: ["Passive: \(set.passive)", "Common: \(set.common)", "Specific: \(set.specific)"],
                                      citation: set.source.citation())
                }
            },
            customTitle: "Custom Trigger Set",
            detail: {
                character.kuruthTriggerSet.map {
                    CatalogChoiceDetail(title: $0.name, summary: $0.summary, citation: $0.source.citation(), facts: [
                        DetailFact(label: "Passive", value: $0.passive),
                        DetailFact(label: "Common", value: $0.common),
                        DetailFact(label: "Specific", value: $0.specific),
                    ])
                }
            },
            choose: { id in character.kuruthTriggerSource = id.map { .catalog($0) } ?? .custom("") }
        )
    }

    @ViewBuilder
    private func triggerRow(_ kind: KuruthTriggers.Kind) -> some View {
        let applies = kind.applies(atHarmony: character.harmony)
        VStack(alignment: .leading, spacing: 2) {
            if character.kuruthTriggerSet != nil {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(kind.name):")
                        .themedText(.label)
                        .frame(minWidth: 100, alignment: .leading)
                    // At the right, like the other rows' values
                    Text(character.kuruthTrigger(kind))
                        .themedText(.body)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                CharacterInfoRowView(label: "\(kind.name):", text: customTrigger(kind))
            }
            if !applies {
                Text("Doesn't apply at Harmony \(character.harmony)")
                    .themedText(.detail)
                    .foregroundStyle(theme.muted)
            }
        }
        .padding(.vertical, character.kuruthTriggerSet != nil ? 4 : 0)
        .opacity(applies ? 1 : 0.45)
        .accessibilityElement(children: character.kuruthTriggerSet != nil ? .combine : .contain)
    }

    private func customTrigger(_ kind: KuruthTriggers.Kind) -> Binding<String> {
        switch kind {
        case .passive: $character.kuruthTriggers.passive
        case .common: $character.kuruthTriggers.common
        case .specific: $character.kuruthTriggers.specific
        }
    }
}
