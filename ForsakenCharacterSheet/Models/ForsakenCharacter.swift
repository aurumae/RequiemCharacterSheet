//
//  ForsakenCharacter.swift
//  ForsakenCharacterSheet
//
//  A Werewolf: The Forsaken character and its save format.
//

import Foundation
import Observation
import SwiftUI

@Observable
final class ForsakenCharacter: Codable {
    /// The version of the save format this app writes.
    /// - 1: the first Forsaken format. Every file has `"game": "forsaken"`.
    static let currentSchemaVersion = 1

    let id: UUID
    let createdAt: Date
    var modifiedAt: Date

    // Character details
    var name: String
    var player: String
    var chronicle: String
    var concept: String
    /// The character's Blood and Bone archetypes: the Wolf and the Man in them, in place of Requiem's Mask and Dirge.
    var bloodSource: TraitSource
    var boneSource: TraitSource
    var auspiceSource: TraitSource
    var tribeSource: TraitSource
    var lodgeSource: TraitSource
    /// The Hunter's Aspect a Pure character took from their tribe; Forsaken take their auspice's.
    var pureHuntersAspect: String

    var attributes: [Attribute]
    var skills: [Skill]
    var merits: [Merit]
    var aspirations: [Aspiration]
    /// Active Conditions, in the order they were added.
    var conditions: [CharacterCondition]

    // Werewolf traits
    var renown: [Renown: Int]
    var primalUrge: Int
    /// Essence in the pool now. The Primal Urge table sets the most it can hold.
    var essence: Int
    var harmony: Int
    var fleshTouchstone: String
    var spiritTouchstone: String
    /// The character's set of Kuruth triggers: one of the book's, or the player's own, written in `kuruthTriggers`.
    var kuruthTriggerSource: TraitSource
    var kuruthTriggers: KuruthTriggers
    /// The form the character is in, which changes their Attributes, Size and Speed. Wounds in Health boxes a
    /// smaller form doesn't have upgrade the ones left (p. 172).
    var form: Form {
        didSet { foldLostHealth() }
    }
    /// The Moon Gift the character uses, if not their auspice's own: an alternate Moon Gift, or the player's own.
    var moonGiftSource: TraitSource?
    /// For a custom Moon Gift, its Facets' names, from one dot up.
    var customMoonFacets: [String]
    /// Other Moon Gifts, unlocked with Experiences and bought a Facet at a time (p. 114).
    var extraMoonGifts: [OwnedMoonGift]
    /// Shadow and Wolf Gift Facets. Moon Gift Facets come with auspice Renown, so aren't listed.
    var facets: [OwnedFacet]
    var rites: [OwnedRite]
    var fetishes: [OwnedFetish]
    var totem: Totem
    /// Size in Hishu form.
    var size: Int
    /// Armor the player enters, e.g. from worn armor or a fetish: general, and ballistic against firearms.
    var armor: Int
    var ballisticArmor: Int
    /// Facets the character may learn free, one for each Renown dot gained in XP Mode (p. 115).
    var renownFacetCredits: [Renown: Int]
    /// What the Favored Form Merit raises and lowers, if the character has it.
    var favoredFormChoices: FavoredFormChoices

    var healthTrack: [HealthBoxFillType]
    var willpowerTrack: [WillpowerBoxFillType]

    var beats: Int
    var experiences: Int
    var xpMode: Bool
    /// Set while the character is being made with guided creation.
    var creation: CreationState?
    var changeLog: [TraitChange]
    /// The Experiences paid for each dot, so lowering a trait in XP Mode refunds them.
    var paidDots: [TraitKey: [Int: Int]]
    /// Whether pickers offer unofficial content as well as the books.
    var showsUnofficialContent: Bool

    init() {
        id = UUID()
        createdAt = Date()
        modifiedAt = createdAt

        name = ""
        player = ""
        chronicle = ""
        concept = ""
        bloodSource = .custom("")
        boneSource = .custom("")
        auspiceSource = .custom("")
        tribeSource = .custom("")
        lodgeSource = .custom("")
        pureHuntersAspect = ""

        attributes = AttributeKind.allCases.map { Attribute($0) }
        // The Chronicles of Darkness core Skills, the same as Requiem's
        skills = SkillList.vampireCore.skills.map { Skill($0) }
        merits = []
        aspirations = [Aspiration()]
        conditions = []

        renown = [:]
        primalUrge = 1
        // A new character starts with 7 (p. 84); the Primal Urge table sets the maximum (p. 93)
        essence = 7
        harmony = 7
        fleshTouchstone = ""
        spiritTouchstone = ""
        kuruthTriggerSource = .custom("")
        kuruthTriggers = KuruthTriggers()
        form = .hishu
        moonGiftSource = nil
        customMoonFacets = []
        extraMoonGifts = []
        facets = []
        rites = []
        fetishes = []
        totem = Totem()
        size = 5
        armor = 0
        ballisticArmor = 0
        renownFacetCredits = [:]
        favoredFormChoices = FavoredFormChoices()

        healthTrack = []
        willpowerTrack = []

        beats = 0
        experiences = 0
        xpMode = false
        creation = nil
        changeLog = []
        paidDots = [:]
        showsUnofficialContent = false
    }

    // MARK: - Saving

    enum CodingKeys: CodingKey {
        case game, schemaVersion, id, createdAt, modifiedAt,
             name, player, chronicle, concept, blood, bone, auspice, tribe, lodge, huntersAspect,
             attributes, skills, merits, aspirations, conditions,
             renown, primalUrge, essence, harmony, fleshTouchstone, spiritTouchstone, kuruthTriggerSet, kuruthTriggers, form,
             moonGift, moonFacets, extraMoonGifts, facets, rites, fetishes, totem, size, armor, ballisticArmor, renownFacetCredits,
             favoredForm,
             healthTrack, willpowerTrack, beats, experiences, xpMode, creation, changeLog, paidDots, showsUnofficialContent
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.game, forKey: .game)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)

        try container.encode(name, forKey: .name)
        try container.encode(player, forKey: .player)
        try container.encode(chronicle, forKey: .chronicle)
        try container.encode(concept, forKey: .concept)
        try container.encode(bloodSource, forKey: .blood)
        try container.encode(boneSource, forKey: .bone)
        try container.encode(auspiceSource, forKey: .auspice)
        try container.encode(tribeSource, forKey: .tribe)
        try container.encode(lodgeSource, forKey: .lodge)
        if !pureHuntersAspect.isEmpty {
            try container.encode(pureHuntersAspect, forKey: .huntersAspect)
        }

        try container.encode(attributes, forKey: .attributes)
        try container.encode(skills, forKey: .skills)
        try container.encode(merits, forKey: .merits)
        try container.encode(aspirations, forKey: .aspirations)
        try container.encode(conditions, forKey: .conditions)

        // Renown by name, e.g. {"cunning": 2}, leaving out Renowns without dots
        let savedRenown = Dictionary(uniqueKeysWithValues: renown.filter { $0.value > 0 }.map { ($0.key.rawValue, $0.value) })
        try container.encode(savedRenown, forKey: .renown)
        try container.encode(primalUrge, forKey: .primalUrge)
        try container.encode(essence, forKey: .essence)
        try container.encode(harmony, forKey: .harmony)
        try container.encode(fleshTouchstone, forKey: .fleshTouchstone)
        try container.encode(spiritTouchstone, forKey: .spiritTouchstone)
        try container.encode(kuruthTriggerSource, forKey: .kuruthTriggerSet)
        // A book set's triggers come from the catalog, so only a custom set's are written
        if kuruthTriggerSource.catalogID == nil {
            try container.encode(kuruthTriggers, forKey: .kuruthTriggers)
        }
        try container.encode(form, forKey: .form)
        try container.encodeIfPresent(moonGiftSource, forKey: .moonGift)
        if !customMoonFacets.isEmpty {
            try container.encode(customMoonFacets, forKey: .moonFacets)
        }
        if !extraMoonGifts.isEmpty {
            try container.encode(extraMoonGifts, forKey: .extraMoonGifts)
        }
        try container.encode(facets, forKey: .facets)
        try container.encode(rites, forKey: .rites)
        try container.encode(fetishes, forKey: .fetishes)
        if totem != Totem() {
            try container.encode(totem, forKey: .totem)
        }
        try container.encode(size, forKey: .size)
        try container.encode(armor, forKey: .armor)
        if ballisticArmor != 0 {
            try container.encode(ballisticArmor, forKey: .ballisticArmor)
        }
        let credits = Dictionary(uniqueKeysWithValues: renownFacetCredits.filter { $0.value > 0 }.map { ($0.key.rawValue, $0.value) })
        if !credits.isEmpty {
            try container.encode(credits, forKey: .renownFacetCredits)
        }
        if favoredFormChoices != FavoredFormChoices() {
            try container.encode(favoredFormChoices, forKey: .favoredForm)
        }

        // Only the boxes on the sheet are saved
        try container.encode(healthTrack.folded(into: health), forKey: .healthTrack)
        try container.encode(willpowerBoxes, forKey: .willpowerTrack)
        try container.encode(beats, forKey: .beats)
        try container.encode(experiences, forKey: .experiences)
        try container.encode(xpMode, forKey: .xpMode)
        try container.encode(changeLog, forKey: .changeLog)
        try container.encode(paidDots, forKey: .paidDots)
        try container.encodeIfPresent(creation, forKey: .creation)
        if showsUnofficialContent {
            try container.encode(showsUnofficialContent, forKey: .showsUnofficialContent)
        }
    }

    /// Missing fields fall back to a new character's, so a file from an older version opens.
    required init(from decoder: Decoder) throws {
        let blank = ForsakenCharacter()
        let catalog = Catalog.bundled
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: blank.id)
        createdAt = try container.decode(.createdAt, default: blank.createdAt)
        modifiedAt = try container.decode(.modifiedAt, default: blank.modifiedAt)

        name = try container.decode(.name, default: "")
        player = try container.decode(.player, default: "")
        chronicle = try container.decode(.chronicle, default: "")
        concept = try container.decode(.concept, default: "")
        // Custom names that now match a catalog entry are linked to it
        bloodSource = try container.decodeTraitSource(.blood, in: catalog.archetypes)
        boneSource = try container.decodeTraitSource(.bone, in: catalog.archetypes)
        auspiceSource = try container.decodeTraitSource(.auspice, in: catalog.auspices)
        tribeSource = try container.decodeTraitSource(.tribe, in: catalog.tribes)
        lodgeSource = try container.decodeTraitSource(.lodge, in: catalog.lodges)
        pureHuntersAspect = try container.decode(.huntersAspect, default: "")

        attributes = try container.decode(.attributes, default: blank.attributes)
        skills = try container.decode(.skills, default: blank.skills)
        let savedMerits: [Merit] = try container.decode(.merits, default: [])
        savedMerits.forEach { $0.relink(in: catalog.merits) }
        merits = savedMerits
        aspirations = try container.decode(.aspirations, default: blank.aspirations)
        let savedConditions: [CharacterCondition] = try container.decode(.conditions, default: [])
        savedConditions.forEach { $0.relink(in: catalog.conditions) }
        conditions = savedConditions

        let savedRenown: [String: Int] = try container.decode(.renown, default: [:])
        renown = Dictionary(uniqueKeysWithValues: savedRenown.compactMap { key, value in Renown(rawValue: key).map { ($0, value) } })
        primalUrge = try container.decode(.primalUrge, default: 1)
        essence = try container.decode(.essence, default: 7)
        harmony = try container.decode(.harmony, default: 7)
        fleshTouchstone = try container.decode(.fleshTouchstone, default: "")
        spiritTouchstone = try container.decode(.spiritTouchstone, default: "")
        kuruthTriggerSource = try container.decodeIfPresent(TraitSource.self, forKey: .kuruthTriggerSet) ?? .custom("")
        kuruthTriggers = try container.decode(.kuruthTriggers, default: KuruthTriggers())
        form = try container.decode(.form, default: .hishu)
        moonGiftSource = try container.decodeIfPresent(TraitSource.self, forKey: .moonGift)
        customMoonFacets = try container.decode(.moonFacets, default: [])
        extraMoonGifts = try container.decode(.extraMoonGifts, default: [])
        // Early drafts listed Moon Gift Facets with the others; they now come from auspice Renown
        let savedFacets: [OwnedFacet] = try container.decode(.facets, default: [])
        facets = savedFacets.filter { $0.source.catalogID.flatMap { catalog.facet($0)?.gift.kind } != .moon }
        rites = try container.decode(.rites, default: [])
        fetishes = try container.decode(.fetishes, default: [])
        totem = try container.decode(.totem, default: Totem())
        size = try container.decode(.size, default: 5)
        armor = try container.decode(.armor, default: 0)
        ballisticArmor = try container.decode(.ballisticArmor, default: 0)
        let savedCredits: [String: Int] = try container.decode(.renownFacetCredits, default: [:])
        renownFacetCredits = Dictionary(uniqueKeysWithValues: savedCredits.compactMap { key, value in Renown(rawValue: key).map { ($0, value) } })
        favoredFormChoices = try container.decode(.favoredForm, default: FavoredFormChoices())

        healthTrack = try container.decode(.healthTrack, default: [])
        willpowerTrack = try container.decode(.willpowerTrack, default: [])
        beats = try container.decode(.beats, default: 0)
        experiences = try container.decode(.experiences, default: 0)
        xpMode = try container.decode(.xpMode, default: false)
        changeLog = try container.decode(.changeLog, default: [])
        paidDots = try container.decode(.paidDots, default: [:])
        creation = try container.decodeIfPresent(CreationState.self, forKey: .creation)
        showsUnofficialContent = try container.decode(.showsUnofficialContent, default: false)
    }
}

extension [String] {
    /// "A", "A or B", "A, B or C": the sheet's own wording, whatever the device's language does with lists.
    func listed(_ conjunction: String) -> String {
        count < 2 ? first ?? "" : dropLast().joined(separator: ", ") + " \(conjunction) " + self[count - 1]
    }
}

// MARK: - Details by name

extension ForsakenCharacter {
    /// The names shown on the sheet. Setting one links to the catalog entry with that name, if there is one.
    var blood: String {
        get { Catalog.bundled.archetypes.name(of: bloodSource) }
        set { bloodSource = Catalog.bundled.archetypes.source(named: newValue) }
    }

    var bone: String {
        get { Catalog.bundled.archetypes.name(of: boneSource) }
        set { boneSource = Catalog.bundled.archetypes.source(named: newValue) }
    }

    var auspice: String {
        get { Catalog.bundled.auspices.name(of: auspiceSource) }
        set { auspiceSource = Catalog.bundled.auspices.source(named: newValue) }
    }

    var tribe: String {
        get { Catalog.bundled.tribes.name(of: tribeSource) }
        set { tribeSource = Catalog.bundled.tribes.source(named: newValue) }
    }

    var lodge: String {
        get { Catalog.bundled.lodges.name(of: lodgeSource) }
        set { lodgeSource = Catalog.bundled.lodges.source(named: newValue) }
    }

    var auspiceEntry: AuspiceEntry? {
        auspiceSource.catalogID.flatMap { Catalog.bundled.auspices.entry($0) }
    }

    var tribeEntry: TribeEntry? {
        tribeSource.catalogID.flatMap { Catalog.bundled.tribes.entry($0) }
    }

    var lodgeEntry: LodgeEntry? {
        lodgeSource.catalogID.flatMap { Catalog.bundled.lodges.entry($0) }
    }

    /// Lodge lore costs a werewolf outside the lodge three times the Experiences (The Pack, p. 80). `lodges` are
    /// those that teach the Merit or rite; none means it isn't lodge lore.
    func lodgeLoreCostMultiplier(_ lodges: [LodgeEntry]) -> Int {
        lodges.isEmpty || isAdherent(ofAny: lodges) ? 1 : 3
    }

    func isAdherent(ofAny lodges: [LodgeEntry]) -> Bool {
        lodges.contains { lodgeSource == .catalog($0.id) }
    }

    /// The lodges that teach a rite the character knows or might learn.
    func lodges(teaching rite: OwnedRite) -> [LodgeEntry] {
        rite.source.catalogID.map { Catalog.bundled.lodges(teachingRite: $0) } ?? []
    }

    var kuruthTriggerSet: KuruthTriggerSetEntry? {
        kuruthTriggerSource.catalogID.flatMap { Catalog.bundled.kuruthTriggers.entry($0) }
    }

    /// The character's trigger of a kind, from their set from the book or their own words.
    func kuruthTrigger(_ kind: KuruthTriggers.Kind) -> String {
        switch kind {
        case .passive: kuruthTriggerSet?.passive ?? kuruthTriggers.passive
        case .common: kuruthTriggerSet?.common ?? kuruthTriggers.common
        case .specific: kuruthTriggerSet?.specific ?? kuruthTriggers.specific
        }
    }

    func renown(_ kind: Renown) -> Int {
        renown[kind] ?? 0
    }

    func setRenown(_ kind: Renown, to rating: Int) {
        // Each Renown dot gained in play brings a free Facet of that Renown in a Gift the character knows (p. 115)
        if xpMode, !isInCreation {
            let change = rating - renown(kind)
            renownFacetCredits[kind] = max((renownFacetCredits[kind] ?? 0) + change, 0)
        }
        renown[kind] = rating > 0 ? rating : nil
    }

    /// The Rank spirits take the character to have, from all their Renown (p. 99).
    var spiritRank: Int {
        switch Renown.allCases.reduce(0, { $0 + renown($1) }) {
        case ..<4: 1
        case 4...7: 2
        case 8...12: 3
        case 13...18: 4
        default: 5
        }
    }

    /// The row of the Primal Urge table for the character's Primal Urge.
    var primalUrgeLevel: PrimalUrgeLevel {
        .level(primalUrge)
    }

    /// Whether the character is one of the Pure, who have no auspice (Shunned by the Moon, p. 14).
    var isPure: Bool {
        tribeEntry?.kind == .pure
    }

    /// The auspice that counts for the rules: none for the Pure, who flay away the Moon's brand.
    var effectiveAuspice: AuspiceEntry? {
        isPure ? nil : auspiceEntry
    }

    /// The character's Hunter's Aspect: the auspice's, or for the Pure the one they chose from their tribe's.
    var huntersAspect: AuspiceEntry.HuntersAspect? {
        guard isPure else { return auspiceEntry?.huntersAspect }
        return tribeEntry?.huntersAspects?.first { $0.name == pureHuntersAspect }
    }

    /// The catalog Moon Gift the character uses: the one chosen, or else their auspice's. `nil` for the Pure, who
    /// have none, and for a custom Moon Gift.
    var moonGift: GiftEntry? {
        guard !isPure else { return nil }
        switch moonGiftSource {
        case .catalog(let id): return Catalog.bundled.gifts.entry(id)
        case .custom: return nil
        case nil: return effectiveAuspice.flatMap { Catalog.bundled.gifts.entry($0.moonGift) }
        }
    }

    /// The Moon Gift's name, or the player's own for a custom one.
    var moonGiftName: String {
        if case .custom(let name) = moonGiftSource { return name }
        return moonGift?.name ?? ""
    }

    /// The Renown that unlocks Moon Gift Facets: the auspice's.
    var moonGiftRenown: Renown? {
        effectiveAuspice?.renown
    }

    /// How many of the Moon Gift's Facets the character has: one for each dot of auspice Renown (p. 85).
    var moonGiftDots: Int {
        guard !isPure, let kind = moonGiftRenown else { return 0 }
        return min(renown(kind), 5)
    }

    /// The catalog Gift of a Moon Gift bought with Experiences; `nil` for the player's own.
    func gift(of owned: OwnedMoonGift) -> GiftEntry? {
        owned.source.catalogID.flatMap { Catalog.bundled.gifts.entry($0) }
    }

    func moonGiftName(_ owned: OwnedMoonGift) -> String {
        Catalog.bundled.gifts.name(of: owned.source)
    }

    /// How many Facets of a bought Moon Gift count: never more than the character's auspice Renown (p. 114).
    func dots(of owned: OwnedMoonGift) -> Int {
        min(owned.dots, moonGiftDots)
    }

    /// The Shadow Gifts the character's tribe and auspice favour, which cost less to learn.
    var affinityGifts: Set<CatalogEntryID> {
        Set((effectiveAuspice?.giftAffinities ?? []) + (tribeEntry?.giftAffinities ?? []))
    }

    /// Whether a Gift is one the tribe or auspice favours, counting an era's Gift as the one it stands in for.
    func hasAffinity(for gift: GiftEntry) -> Bool {
        affinityGifts.contains(gift.id) || gift.replaces.map(affinityGifts.contains) == true
    }

    /// The Gift a known Facet belongs to.
    func gift(of facet: OwnedFacet) -> GiftEntry? {
        facet.source.catalogID.flatMap { Catalog.bundled.facet($0)?.gift }
    }

    /// Size in the current form.
    var effectiveSize: Int {
        size(in: form)
    }

    func facetName(_ facet: OwnedFacet) -> String {
        if let id = facet.source.catalogID {
            return Catalog.bundled.facet(id)?.facet.name ?? id
        }
        if case .custom(let name) = facet.source { return name }
        return ""
    }

    func riteName(_ rite: OwnedRite) -> String {
        Catalog.bundled.rites.name(of: rite.source)
    }

    func riteRating(_ rite: OwnedRite) -> Int {
        rite.source.catalogID.flatMap { Catalog.bundled.rites.entry($0)?.rating } ?? rite.customRating
    }
}

// MARK: - Shared sheet sections

extension ForsakenCharacter: SheetCharacter {
    var conditionCatalog: CatalogIndex<ConditionEntry> {
        Catalog.bundled.conditions
    }

    func editableMaximum(for key: TraitKey, upTo cap: Int) -> Int {
        creationMaximum(for: key, upTo: cap) ?? cap
    }

    /// During guided creation, only while fewer than three are taken.
    var canAddSpecialty: Bool {
        !isInCreation || creationReport.specialties.remaining > 0
    }

    func creationAllowsMerit(_ entry: MeritEntry?, rating: Int) -> Bool {
        creationAllows(.merit(entry, rating: rating))
    }

    func categoryAccessory(for category: TraitCategory, skills: Bool) -> AnyView? {
        // During guided creation, the player chooses where the 5/4/3 or 11/7/4 dots go
        isInCreation ? AnyView(CreationPriorityMenu(character: self, category: category, skills: skills)) : nil
    }

    func attributeNote(for kind: AttributeKind) -> String? {
        var notes: [String] = []
        if let change = form.attributeModifiers[kind], change != 0 {
            notes.append("\(change > 0 ? "+" : "−")\(abs(change)) in \(form.name)")
        }
        let favored = favoredFormModifier(to: kind, in: form)
        if favored != 0 {
            notes.append("\(favored > 0 ? "+" : "−")\(abs(favored)) from Favored Form")
        }
        let totem = totem.dots(for: .attribute, kind.rawValue)
        if totem > 0 { notes.append("+\(totem) from the totem") }
        if attributeBonus(for: kind) > totem { notes.append("+1 from Embodiment of the Firstborn") }
        notes += powerNotes(for: kind)
        return notes.isEmpty ? nil : notes.joined(separator: " · ")
    }

    /// Attributes and Skills can go as high as Primal Urge allows (p. 93).
    var baseRatingCap: Int {
        primalUrgeLevel.traitMaximum
    }

    /// The Attribute in the current form, e.g. Strength +3 in Gauru.
    /// Every dot on the sheet: those bought, those from the totem and Embodiment of the Firstborn, and the form's.
    func totalAttributeRating(for attribute: Attribute) -> Int {
        max(attribute.rating + attributeBonus(for: attribute.kind) + powerBonus(to: attribute.kind, in: form)
            + formModifier(to: attribute.kind, in: form), 0)
    }

    /// The dots that count: bonus dots may only go past the Primal Urge maximum as far as their sources allow.
    func countedAttributeRating(for attribute: Attribute) -> Int {
        rating(attribute.kind, in: form)
    }

    func skillBonus(for skill: Skill) -> Int {
        totem.dots(for: .skill, skill.skillID.rawValue) + powerBonus(to: skill.skillID, in: form)
    }

    func countedSkillRating(for skill: Skill) -> Int {
        skillRating(skill.skillID, in: form)
    }

    /// A Skill's dots that count in a form: a totem's dots can go one past the maximum, however many it grants
    /// (p. 93), and active Gifts' come on top.
    func skillRating(_ id: SkillID, in form: Form) -> Int {
        let bought = rating(of: id)
        let totemDots = totem.dots(for: .skill, id.rawValue)
        return min(bought + totemDots, max(bought, baseRatingCap + (totemDots > 0 ? 1 : 0))) + powerBonus(to: id, in: form)
    }

    func grantedSpecialties(for skill: Skill) -> [String] {
        totem.advantages.filter { $0.kind == .specialty && $0.target == skill.skillID.rawValue && !$0.detail.isEmpty }.map(\.detail)
    }


    var meritCategoryOrder: [MeritEntry.Category] {
        [.werewolf, .mental, .physical, .social, .fighting, .other, .supernatural, .human]
    }

    /// A Condition's choices by faction, e.g. Siskur-Dah's ritemaster tribes: the character's own side first, then
    /// the other side's apart, as Pure and Forsaken only rarely hunt together.
    func noteOptionGroups(for entry: ConditionEntry) -> [ConditionNoteOptionGroup] {
        guard !entry.noteOptions.isEmpty else { return [] }
        // Choices that aren't grouped, e.g. the kinds of Outlaw, are one plain list
        guard entry.noteOptions.contains(where: { $0.group != nil }) else {
            return [ConditionNoteOptionGroup(title: "", options: entry.noteOptions)]
        }
        let ownGroup = isPure ? "pure" : "forsaken"
        let otherGroup = isPure ? "forsaken" : "pure"
        // Others in the catalog, e.g. Bale Hound lodges and the Urighur, aren't offered to player characters yet
        let own = entry.noteOptions.filter { ($0.group ?? ownGroup) == ownGroup }
        let other = entry.noteOptions.filter { $0.group == otherGroup }
        // A ritemaster may give their lodge's benefit in place of their tribe's, to everyone on the hunt (The Pack, p. 80)
        let lodges = entry.noteOptions.filter { $0.group == "lodge" }
        var groups = [ConditionNoteOptionGroup(title: isPure ? "Pure Tribes" : "Forsaken Tribes", options: own)]
        if !lodges.isEmpty {
            groups.append(ConditionNoteOptionGroup(title: "Lodges", options: lodges))
        }
        if !other.isEmpty {
            groups.append(ConditionNoteOptionGroup(title: isPure ? "Forsaken Tribes" : "Pure Tribes",
                                                   warning: isPure ? "The Forsaken are your enemies" : "The Pure are your enemies",
                                                   options: other))
        }
        return groups
    }

    func meritUnavailableReason(_ entry: MeritEntry) -> String? {
        entry.category == .human ? "Only for humans" : nil
    }

    func meritCategoryTitle(_ category: MeritEntry.Category) -> String {
        switch category {
        case .werewolf: "Werewolf"
        case .mental: "Mental"
        case .physical: "Physical"
        case .social: "Social"
        case .fighting: "Fighting"
        case .supernatural: "Supernatural"
        case .other: "Other"
        case .human: "Human"
        default: category.rawValue.capitalized
        }
    }

    /// The shared prerequisites, and Forsaken's: Renown, Primal Urge, Harmony, tribe and auspice. A Merit a lodge
    /// teaches also asks for the lodge, though a werewolf outside it can learn it at three times the cost.
    func prerequisiteChecks(for entry: MeritEntry) -> [PrerequisiteCheck] {
        let catalog = Catalog.bundled
        let lodges = catalog.lodges(teachingMerit: entry.id)
        let lodgeCheck = lodges.isEmpty ? [] : [PrerequisiteCheck(
            description: "\(Self.lodgeRequirement(lodges)) (three times the cost otherwise)", isMet: isAdherent(ofAny: lodges))]
        return lodgeCheck + prerequisiteChecks(entry.prerequisites, anyOf: entry.prerequisitesAnyOf) { prerequisite in
            if let common = commonCheck(prerequisite, merits: catalog.merits) {
                return common
            }
            let id = prerequisite.id ?? ""
            let minimum = prerequisite.minimum ?? 1
            switch prerequisite.kind {
            case .renown:
                guard let kind = Renown(rawValue: id) else { return unknownCheck(prerequisite) }
                return PrerequisiteCheck(description: "\(kind.name) \(minimum)", isMet: renown(kind) >= minimum)
            case .primalUrge:
                return PrerequisiteCheck(description: "Primal Urge \(minimum)", isMet: primalUrge >= minimum)
            case .harmony:
                return PrerequisiteCheck(description: "Harmony \(minimum)", isMet: harmony >= minimum)
            case .tribe:
                let name = catalog.tribes.entry(id)?.name ?? id
                return PrerequisiteCheck(description: "Tribe: \(name)", isMet: tribeSource == .catalog(id))
            case .notTribe:
                let name = catalog.tribes.entry(id)?.name ?? id
                return PrerequisiteCheck(description: prerequisite.text ?? "Not of the \(name)", isMet: tribeSource != .catalog(id))
            case .auspice:
                let name = catalog.auspices.entry(id)?.name ?? id
                return PrerequisiteCheck(description: "Auspice: \(name)", isMet: effectiveAuspice?.id == id)
            default:
                return unknownCheck(prerequisite)
            }
        }
    }
}

// MARK: - Experiences

extension ForsakenCharacter: ExperienceCharacter {
    var meritCatalog: CatalogIndex<MeritEntry> {
        Catalog.bundled.merits
    }

    /// Every trait that costs Experiences. Harmony can't be bought (p. 104), and fetishes are made, not bought.
    var traitSnapshot: TraitSnapshot {
        var snapshot = TraitSnapshot()
        addSharedTraits(to: &snapshot)
        for kind in Renown.allCases {
            snapshot.levels[TraitKey(.renown, kind.rawValue)] = renown(kind)
            snapshot.names[TraitKey(.renown, kind.rawValue)] = kind.name
        }
        for gift in extraMoonGifts {
            let key = TraitKey(.moonGift, gift.id.uuidString)
            snapshot.levels[key] = gift.dots
            snapshot.names[key] = moonGiftName(gift)
        }
        for facet in facets {
            let key = TraitKey(.facet, facet.id.uuidString)
            snapshot.levels[key] = 1
            snapshot.names[key] = facetName(facet)
        }
        for rite in rites {
            let key = TraitKey(.rite, rite.id.uuidString)
            // A Rite costs 1 Experience per dot (p. 85)
            snapshot.levels[key] = riteRating(rite)
            snapshot.names[key] = riteName(rite)
        }
        snapshot.levels[TraitKey(.primalUrge, "primalUrge")] = primalUrge
        snapshot.names[TraitKey(.primalUrge, "primalUrge")] = "Primal Urge"
        return snapshot
    }

    /// e.g. "Lodge: Lodge of the Screaming Moon or The Temple of Apollo".
    static func lodgeRequirement(_ lodges: [LodgeEntry]) -> String {
        "Lodge: " + lodges.map(\.name).listed("or")
    }

    /// The book's Experience costs (pp. 84–85). A Wolf Gift Facet costs 1 (decided 2026-11-12). A lodge's Merits and
    /// rites cost a werewolf outside it three times as much (The Pack, p. 80).
    func experienceCost(of key: TraitKey, level: Int) -> Int {
        if key.kind == .merit, let id = merits.first(where: { $0.id.uuidString == key.id })?.source.catalogID {
            return lodgeLoreCostMultiplier(Catalog.bundled.lodges(teachingMerit: id))
        }
        if let shared = sharedExperienceCost(of: key.kind) {
            return shared
        }
        switch key.kind {
        case .renown:
            return 3
        case .rite:
            return rites.first { $0.id.uuidString == key.id }.map { lodgeLoreCostMultiplier(lodges(teaching: $0)) } ?? 1
        case .primalUrge:
            return 5
        case .moonGift:
            // Unlocking another Moon Gift brings its first Facet; the rest are bought one at a time (p. 114)
            return level == 1 ? FacetPrice.otherGift : FacetPrice.furtherFacet
        case .facet:
            guard let facet = facets.first(where: { $0.id.uuidString == key.id }) else { return FacetPrice.furtherFacet }
            return facetCost(facet)
        default:
            return 0
        }
    }

    /// What a Facet on the sheet cost: nothing if learned with Renown, and otherwise what its Gift's Facets cost,
    /// given the character's other Facets.
    private func facetCost(_ facet: OwnedFacet) -> Int {
        if facet.learnedWithRenown { return 0 }
        guard let gift = gift(of: facet) else { return FacetPrice.furtherFacet }
        return experienceCost(ofFacetIn: gift, unlocked: facets.contains { $0.id != facet.id && self.gift(of: $0)?.id == gift.id })
    }

    /// A Facet's cost in Experiences: 1 for a Wolf Gift's; 2 for another Facet of a Gift already unlocked; otherwise
    /// it unlocks the Gift, for 3 if the tribe or auspice favours it and 5 if not (pp. 85, 115).
    func experienceCost(ofFacetIn gift: GiftEntry, unlocked: Bool) -> Int {
        if gift.kind == .wolf { return FacetPrice.wolfFacet }
        if unlocked { return FacetPrice.furtherFacet }
        return gift.kind == .shadow && hasAffinity(for: gift) ? FacetPrice.affinityGift : FacetPrice.otherGift
    }

    func refundsWhenLowered(_ kind: TraitKind) -> Bool {
        true
    }

    var traitKindOrder: [TraitKind] {
        [.attribute, .skill, .specialty, .merit, .renown, .moonGift, .facet, .rite, .primalUrge, .condition]
    }

    func displayName(of kind: TraitKind) -> String {
        switch kind {
        case .attribute: "Attribute"
        case .skill: "Skill"
        case .specialty: "Specialty"
        case .merit: "Merit"
        case .renown: "Renown"
        case .moonGift: "Moon Gift"
        case .facet: "Facet"
        case .rite: "Rite"
        case .primalUrge: "Primal Urge"
        case .condition: "Condition"
        default: kind.rawValue
        }
    }
}

extension ForsakenCharacter: ChroniclesCharacter {
    /// Stamina + Size in the current form (p. 96).
    var health: Int {
        rating(.stamina, in: form) + effectiveSize
            + powerTotal(in: form) { if case .health(let amount) = $0 { amount } else { nil } }
    }
}

// MARK: - Store and list

/// A saved Forsaken character as shown in the character list.
struct ForsakenCharacterSummary: StoredCharacterSummary {
    let id: UUID
    let name: String
    let auspice: String
    let tribe: String
    let modifiedAt: Date?
    let isReadable: Bool

    var listDetails: [String] {
        [auspice, tribe]
    }
}

extension ForsakenCharacter: StoredCharacter {
    static var game: String { "forsaken" }

    func summary() -> ForsakenCharacterSummary {
        ForsakenCharacterSummary(id: id, name: name, auspice: isPure ? "" : auspice, tribe: tribe, modifiedAt: modifiedAt, isReadable: true)
    }

    static func unreadableSummary(id: UUID) -> ForsakenCharacterSummary {
        ForsakenCharacterSummary(id: id, name: "", auspice: "", tribe: "", modifiedAt: nil, isReadable: false)
    }
}

extension ForsakenCharacter: ListedCharacter {
    static var offersGuidedCreation: Bool { true }

    static func newCharacter(guided: Bool) -> ForsakenCharacter {
        guided ? .guided() : ForsakenCharacter()
    }
}

// MARK: - Derived traits

extension ForsakenCharacter {
    /// The effects of the character's catalog Merits with at least one dot, e.g. Fast Reflexes on Initiative.
    private func meritEffectTotal(_ select: (Effect) -> Amount?) -> Int {
        // Each Merit's own dots with any the totem grants, and granted Merits not yet given a row (see
        // `syncTotemMerits`)
        let owned = merits.compactMap { merit in merit.entry.map { ($0, merit.rating + meritBonus(for: $0.id)) } }
        let ownedIDs = Set(owned.map(\.0.id))
        let unlisted = Set(totem.advantages.filter { $0.kind == .merit }.map(\.target)).subtracting(ownedIDs)
            .compactMap { id in Catalog.bundled.merits.entry(id).map { ($0, meritBonus(for: id)) } }
        return (owned + unlisted).reduce(0) { total, pair in
            guard pair.1 > 0 else { return total }
            return total + pair.0.effects.reduce(0) { $0 + (select($1)?.value(forRating: pair.1) ?? 0) }
        }
    }

    /// Dots the pack's totem grants in a Merit (p. 93).
    func meritBonus(for id: CatalogEntryID) -> Int {
        totem.advantages.filter { $0.kind == .merit && $0.target == id }.reduce(0) { $0 + $1.dots }
    }

    /// A Merit the totem grants is taken whatever its prerequisites.
    func prerequisitesApply(to merit: Merit) -> Bool {
        merit.source.catalogID.map { meritBonus(for: $0) == 0 } ?? true
    }

    /// Gives every Merit the totem grants a row in Merits, with no dots of the character's own, so its dots show in
    /// ink and the character can add their own; and takes away rows the totem gave but no longer grants, if the
    /// character hasn't bought dots in them.
    func syncTotemMerits(previous: [TotemAdvantage] = []) {
        let granted = Set(totem.advantages.filter { $0.kind == .merit }.map(\.target))
        for advantage in totem.advantages where advantage.kind == .merit
            && !merits.contains(where: { $0.source == .catalog(advantage.target) }) {
            merits.append(Merit(source: .catalog(advantage.target), qualifier: advantage.detail.isEmpty ? nil : advantage.detail,
                                rating: 0))
        }
        let dropped = Set(previous.filter { $0.kind == .merit }.map(\.target)).subtracting(granted)
        merits.removeAll { merit in
            merit.rating == 0 && merit.source.catalogID.map(dropped.contains) == true
        }
    }

    /// An Attribute's dots in a form (pp. 96–97).
    func rating(_ kind: AttributeKind, in form: Form) -> Int {
        max(countedRating(of: kind) + powerBonus(to: kind, in: form) + formModifier(to: kind, in: form), 0)
    }

    /// What a form does to an Attribute: the form's own change, and Favored Form's.
    func formModifier(to kind: AttributeKind, in form: Form) -> Int {
        (form.attributeModifiers[kind] ?? 0) + favoredFormModifier(to: kind, in: form)
    }

    /// A catalog Merit's dots: the character's own and any the totem grants.
    func meritDots(_ id: CatalogEntryID) -> Int {
        (merits.filter { $0.source == .catalog(id) }.map(\.rating).max() ?? 0) + meritBonus(for: id)
    }

    /// The form the Favored Form Merit is taken for, and its dots (p. 106).
    var favoredForm: (form: Form, dots: Int)? {
        let dots = meritDots("favored-form")
        guard dots > 0, let name = merits.first(where: { $0.source == .catalog("favored-form") })?.qualifier,
              let form = Form.allCases.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }), form != .hishu
        else { return nil }
        return (form, dots)
    }

    /// Favored Form's change to an Attribute in a form: a dot more in the favored form for the Attributes chosen at
    /// its second and fourth dots, and a dot less for each drawback set on another form.
    func favoredFormModifier(to kind: AttributeKind, in form: Form) -> Int {
        guard let favored = favoredForm else { return 0 }
        if form == favored.form {
            let raised = favoredFormChoices.attributes.prefix(favored.dots >= 4 ? 2 : favored.dots >= 2 ? 1 : 0)
            return raised.contains(kind) ? 1 : 0
        }
        return -favoredFormChoices.drawbacks.prefix(favored.dots).filter { $0.form == form && $0.attribute == kind }.count
    }

    /// Dots an Attribute gets beyond those bought: the totem's, and Embodiment of the Firstborn's.
    func attributeBonus(for kind: AttributeKind) -> Int {
        totem.dots(for: .attribute, kind.rawValue) + (embodiesFirstborn(in: kind) ? 1 : 0)
    }

    /// How far bonus dots may take an Attribute past the Primal Urge maximum. Each source allows one, and they stack
    /// (the user's ruling, 2026-11-16), but a totem allows only one however many dots it grants.
    func overLimitAllowance(for kind: AttributeKind) -> Int {
        (totem.dots(for: .attribute, kind.rawValue) > 0 ? 1 : 0) + (embodiesFirstborn(in: kind) ? 1 : 0)
    }

    /// The Attribute's dots that count, before the form: bought and bonus dots, up to the maximum plus the allowance.
    func countedRating(of kind: AttributeKind) -> Int {
        let bought = rating(of: kind)
        return min(bought + attributeBonus(for: kind), max(bought, baseRatingCap + overLimitAllowance(for: kind)))
    }

    /// Embodiment of the Firstborn adds a dot to the Attribute it names, which may go one past the maximum (p. 106).
    private func embodiesFirstborn(in kind: AttributeKind) -> Bool {
        merits.contains { merit in
            merit.source == .catalog("embodiment-of-the-firstborn") && merit.rating > 0
                && merit.qualifier.map { $0.caseInsensitiveCompare(kind.name) == .orderedSame } == true
        }
    }

    /// Size in a form, with Merits such as Giant.
    func size(in form: Form) -> Int {
        size + form.sizeModifier + meritEffectTotal { if case .size(let amount) = $0 { amount } else { nil } }
            + powerTotal(in: form) { if case .size(let amount) = $0 { amount } else { nil } }
    }

    /// Strength + Dexterity + the species factor: 5, or 8 for the wolf forms.
    func speed(in form: Form) -> Int {
        rating(.strength, in: form) + rating(.dexterity, in: form) + 5 + form.speciesSpeedBonus
            + meritEffectTotal { if case .speed(let amount) = $0 { amount } else { nil } }
            + powerTotal(in: form) { if case .speed(let amount) = $0 { amount } else { nil } }
    }

    /// The lower of Dexterity and Wits, plus Athletics or a Skill a Merit allows, e.g. Defensive Combat (Brawl).
    /// Instinctive Defense takes the higher of the two in Urshul and Urhan (p. 109).
    func defense(in form: Form, using skill: SkillID = .athletics) -> Int {
        let dexterity = rating(.dexterity, in: form), wits = rating(.wits, in: form)
        let instinctive = (form == .urshul || form == .urhan) && meritDots("instinctive-defense") > 0
        return (instinctive ? max(dexterity, wits) : min(dexterity, wits)) + skillRating(skill, in: form)
            + meritEffectTotal { if case .defense(let amount) = $0 { amount } else { nil } }
            + powerTotal(in: form) { if case .defense(let amount) = $0 { amount } else { nil } }
    }

    /// Dexterity + Composure.
    func initiative(in form: Form) -> Int {
        rating(.dexterity, in: form) + rating(.composure, in: form)
            + meritEffectTotal { if case .initiative(let amount) = $0 { amount } else { nil } }
            + powerTotal(in: form) { if case .initiative(let amount) = $0 { amount } else { nil } }
    }

    /// Skills Merits let the character use for Defense in place of Athletics, e.g. Defensive Combat (Brawl).
    var alternativeDefenseSkills: [SkillID] {
        merits.filter { $0.rating > 0 }.flatMap { merit -> [SkillID] in
            guard merit.entry?.effects.contains(.defenseSkillFromQualifier) == true,
                  let qualifier = merit.qualifier, let skill = SkillDefinition.named(qualifier)?.id else { return [] }
            return [skill]
        }
    }
}

// MARK: - Gift and rite effects

/// A Gift Facet's or rite's effect on the sheet, with the dots it's worked out from.
struct AppliedPower {
    let name: String
    let effect: Effect
    /// The Facet's Renown dots (the auspice's for a Moon Gift), or the rite's dots.
    let rating: Int
    /// The forms it applies in; `nil` for every form.
    let forms: [Form]?
}

extension ForsakenCharacter {
    /// The effects that apply now: passive Facets, those the player has switched on, active rites and the lodge's.
    var appliedPowers: [AppliedPower] {
        var powers: [AppliedPower] = []
        if let gift = moonGift {
            for facet in gift.facets where (facet.dots ?? 0) <= moonGiftDots && facet.passive == true {
                powers += (facet.effects ?? []).map { AppliedPower(name: facet.name, effect: $0, rating: moonGiftDots, forms: facet.effectForms) }
            }
        }
        for owned in extraMoonGifts where !isPure {
            for facet in gift(of: owned)?.facets ?? [] where (facet.dots ?? 0) <= dots(of: owned) && facet.passive == true {
                powers += (facet.effects ?? []).map { AppliedPower(name: facet.name, effect: $0, rating: moonGiftDots, forms: facet.effectForms) }
            }
        }
        for owned in facets {
            guard let found = owned.source.catalogID.flatMap({ Catalog.bundled.facet($0) }), let effects = found.facet.effects,
                  found.facet.passive == true || owned.isActive else { continue }
            let rating = found.facet.renown.map { self.renown($0) } ?? moonGiftDots
            powers += effects.map { AppliedPower(name: found.facet.name, effect: $0, rating: rating, forms: found.facet.effectForms) }
        }
        for rite in rites where rite.isActive {
            guard let entry = rite.source.catalogID.flatMap({ Catalog.bundled.rites.entry($0) }) else { continue }
            powers += (entry.effects ?? []).map { AppliedPower(name: entry.name, effect: $0, rating: entry.rating, forms: nil) }
        }
        // A lodge's own, measured in Primal Urge, e.g. the Lodge of the Field's Essence (p. 277)
        if let lodge = lodgeEntry {
            powers += (lodge.effects ?? []).map { AppliedPower(name: lodge.name, effect: $0, rating: primalUrge, forms: nil) }
        }
        return powers
    }

    /// Adds up the powers' amounts that `select` picks out, in a form.
    func powerTotal(in form: Form, _ select: (Effect) -> Amount?) -> Int {
        appliedPowers.reduce(0) { total, power in
            guard power.forms?.contains(form) ?? true, let amount = select(power.effect) else { return total }
            return total + amount.value(forRating: power.rating)
        }
    }

    /// Dots active powers add to an Attribute, which may go past the usual maximum.
    func powerBonus(to kind: AttributeKind, in form: Form) -> Int {
        powerTotal(in: form) { if case .attribute(let target, let amount) = $0, target == kind { amount } else { nil } }
    }

    func powerBonus(to skill: SkillID, in form: Form) -> Int {
        powerTotal(in: form) { if case .skill(let target, let amount) = $0, target == skill { amount } else { nil } }
    }

    /// The powers adding to an Attribute now, by name, e.g. "+2 from Primal Strength".
    func powerNotes(for kind: AttributeKind) -> [String] {
        appliedPowers.compactMap { power in
            guard power.forms?.contains(form) ?? true, case .attribute(let target, let amount) = power.effect, target == kind else { return nil }
            return "+\(amount.value(forRating: power.rating)) from \(power.name)"
        }
    }

    var willpowerBonus: Int {
        powerTotal(in: form) { if case .willpower(let amount) = $0 { amount } else { nil } }
    }

    /// The most Essence the character can hold: the Primal Urge table's, and any Gift's, rite's or lodge's.
    var essenceMaximum: Int {
        primalUrgeLevel.essenceMaximum + powerTotal(in: form) { if case .essenceMaximum(let amount) = $0 { amount } else { nil } }
    }

    // MARK: Armor and combat

    /// General and ballistic armor in a form: what the player enters, Fortified Form's in its form (p. 106), and
    /// any an active rite gives, e.g. Raiment of the Storm.
    func armor(in form: Form) -> (general: Int, ballistic: Int) {
        let fortified = merits.filter { $0.source == .catalog("fortified-form") && $0.qualifier?.caseInsensitiveCompare(form.name) == .orderedSame }
            .reduce((0, 0)) { total, merit in
                let rating = merit.rating + meritBonus(for: "fortified-form")
                let armor = rating >= 5 ? (2, 2) : rating >= 4 ? (1, 1) : rating >= 3 ? (1, 0) : (0, 0)
                return (total.0 + armor.0, total.1 + armor.1)
            }
        let powers = powerTotal(in: form) { if case .armor(let amount) = $0 { amount } else { nil } }
        return (armor + fortified.0 + powers, ballisticArmor + fortified.1)
    }

    /// Strength + Brawl, the pool for claws and fists, with a die off when untrained (p. 154).
    func brawlPool(in form: Form) -> Int {
        let brawl = skillRating(.brawl, in: form)
        return rating(.strength, in: form) + (brawl > 0 ? brawl : TraitCategory.physical.unskilledPenalty)
    }

    /// Strength + Weaponry and Dexterity + Firearms, for the forms with hands that can use them.
    func weaponryPool(in form: Form) -> Int? {
        form == .hishu || form == .dalu ? rating(.strength, in: form) + skillRating(.weaponry, in: form) : nil
    }

    func firearmsPool(in form: Form) -> Int? {
        form == .hishu || form == .dalu ? rating(.dexterity, in: form) + skillRating(.firearms, in: form) : nil
    }

    // MARK: Dice pools

    /// A dice pool such as "Wits + Occult + Wisdom vs Resistance" worked out in a form: the character's Attributes,
    /// Skills (with the penalty for one with no dots), Renown and Primal Urge before the "vs" or "−". `nil` if any of
    /// those traits isn't one the sheet has, e.g. "Varies".
    func worked(_ pool: String, in form: Form) -> WorkedDicePool? {
        var traits = pool, against = ""
        for (separator, mark) in [(" versus ", "vs "), (" vs ", "vs "), (" - ", "− "), (" − ", "− ")] {
            if let range = pool.range(of: separator) {
                traits = String(pool[..<range.lowerBound])
                against = mark + pool[range.upperBound...]
                break
            }
        }
        var dice = 0
        for term in traits.components(separatedBy: " + ") {
            let name = term.trimmingCharacters(in: .whitespaces)
            if let kind = AttributeKind.allCases.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                dice += rating(kind, in: form)
            } else if let skill = SkillDefinition.named(name) {
                let dots = skillRating(skill.id, in: form)
                dice += dots > 0 ? dots : skill.category.unskilledPenalty
            } else if let kind = Renown.allCases.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                dice += renown(kind)
            } else if name.caseInsensitiveCompare("Primal Urge") == .orderedSame {
                dice += primalUrge
            } else {
                return nil
            }
        }
        return WorkedDicePool(dice: dice, traits: traits, against: against)
    }

    // MARK: Facets from Renown

    /// Whether the Gift is unlocked, so a Facet of it can be learned with Renown: one of its Facets is known, or
    /// it's a Wolf Gift, which every werewolf has (p. 115).
    func hasUnlocked(_ gift: GiftEntry) -> Bool {
        gift.kind == .wolf || facets.contains { self.gift(of: $0)?.id == gift.id }
    }

    /// Whether a Facet can be learned free now, with a new dot of its Renown.
    func canLearnFree(_ facet: GiftEntry.Facet, of gift: GiftEntry) -> Bool {
        guard let renown = facet.renown, !isInCreation else { return false }
        return (renownFacetCredits[renown] ?? 0) > 0 && hasUnlocked(gift)
    }

    /// What learning a Facet would cost now: nothing with a new dot of its Renown, or else Experiences.
    func price(of facet: GiftEntry.Facet, in gift: GiftEntry) -> FacetPrice {
        if canLearnFree(facet, of: gift), let renown = facet.renown {
            return .renown(renown)
        }
        let unlocked = hasUnlocked(gift)
        return .experiences(experienceCost(ofFacetIn: gift, unlocked: unlocked), unlocksGift: !unlocked)
    }

    /// The Renowns with a free Facet waiting to be learned.
    var renownsWithFreeFacets: [Renown] {
        guard xpMode, !isInCreation else { return [] }
        return Renown.allCases.filter { (renownFacetCredits[$0] ?? 0) > 0 }
    }

    /// The Facets a new dot of Renown could bring free: those of that Renown the character doesn't know, in Wolf
    /// Gifts and the Shadow Gifts they've unlocked (p. 115). If there are none, the free Facet waits for a new Gift.
    func freeFacetChoices(for renown: Renown) -> [(gift: GiftEntry, facet: GiftEntry.Facet)] {
        let known = Set(facets.compactMap(\.source.catalogID))
        return Catalog.bundled.gifts.all.filter { $0.kind != .moon && hasUnlocked($0) }.flatMap { gift in
            gift.facets.filter { $0.renown == renown && !known.contains($0.id) }.map { (gift, $0) }
        }
    }

    /// Learns a Facet, free with Renown if it can be.
    func learn(_ facet: GiftEntry.Facet, of gift: GiftEntry) {
        let free = canLearnFree(facet, of: gift)
        if free, let renown = facet.renown {
            renownFacetCredits[renown] = (renownFacetCredits[renown] ?? 1) - 1
        }
        facets.append(OwnedFacet(source: .catalog(facet.id), learnedWithRenown: free))
    }

    /// Forgets a Facet, giving back the free Facet if it was learned with Renown.
    func forget(_ owned: OwnedFacet) {
        if owned.learnedWithRenown, let renown = owned.source.catalogID.flatMap({ Catalog.bundled.facet($0) })?.facet.renown {
            renownFacetCredits[renown, default: 0] += 1
        }
        facets.removeAll { $0.id == owned.id }
    }
}
