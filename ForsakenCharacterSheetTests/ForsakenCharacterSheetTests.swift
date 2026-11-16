//
//  ForsakenCharacterSheetTests.swift
//  ForsakenCharacterSheetTests
//

import Foundation
import Testing
import UIKit
@testable import ForsakenCharacterSheet

@MainActor
struct ForsakenSaveTests {
    private func makeStore() -> CharacterFileStore<ForsakenCharacter> {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        return CharacterFileStore(directory: directory, legacyDefaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test func savesSayTheyAreForsaken() throws {
        let character = ForsakenCharacter()
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(character)) as? [String: Any])
        #expect(object["game"] as? String == "forsaken")
        #expect(object["schemaVersion"] as? Int == ForsakenCharacter.currentSchemaVersion)
    }

    @Test func characterLoadsBackAsSaved() throws {
        let store = makeStore()
        let character = ForsakenCharacter()
        character.name = "Mara Greyfoot"
        character.blood = "The Guardian"
        character.bone = "The Survivor"
        character.auspice = "Irraka"
        character.tribe = "Hunters in Darkness"
        character.attributes.first { $0.kind == .wits }?.rating = 3
        character.skills.first { $0.skillID == .investigation }?.specialties = ["Tracking"]
        character.merits.append(Merit(source: .catalog("fast-reflexes"), rating: 2))
        try store.save(character)

        let loaded = try store.load(character.id)
        #expect(loaded.name == "Mara Greyfoot")
        #expect(loaded.blood == "The Guardian" && loaded.bone == "The Survivor")
        #expect(loaded.rating(of: .wits) == 3)
        #expect(loaded.skill(.investigation)?.specialties == ["Tracking"])
        #expect(loaded.merits.map(\.name) == ["Fast Reflexes"])
        #expect(store.summaries.first?.listDetails == ["Irraka", "Hunters in Darkness"])
    }

    @Test func requiemCharactersAreRefused() throws {
        let store = makeStore()
        // Requiem's files have no game key
        let requiem = Data(#"{"schemaVersion": 12, "name": "Marcus Vale", "clan": "Ventrue"}"#.utf8)
        #expect(throws: CharacterStoreError.otherGame("requiem")) { try store.prepareImport(of: requiem) }
    }

    @Test func newerFormatsAreRefused() throws {
        let store = makeStore()
        let data = Data(#"{"game": "forsaken", "schemaVersion": 99, "name": "Mara Greyfoot"}"#.utf8)
        #expect(throws: CharacterStoreError.newerFormat(version: 99)) { try store.prepareImport(of: data) }
    }
}

@MainActor
struct ForsakenRulesTests {
    @Test func catalogHasTheChroniclesCoreMeritsAndConditions() {
        #expect(Catalog.bundled.merits.entry("fast-reflexes") != nil)
        #expect(!Catalog.bundled.conditions.all.isEmpty)
        #expect(Catalog.bundled.books.map(\.id) == ["wtf2e-core", "cofd-core", "night-horrors-shunned-by-the-moon", "the-pack", "giver-of-gifts-1", "giver-of-gifts-2"])
    }

    @Test func werewolfCoreBookIsLoaded() {
        let catalog = Catalog.bundled
        let fromCore = { (source: SourceReference) in source.book == "wtf2e-core" }
        #expect(catalog.auspices.all.count == 5)
        #expect(catalog.tribes.all.filter { fromCore($0.source) }.count == 6)
        #expect(catalog.lodges.all.filter { fromCore($0.source) }.count == 8)
        #expect(catalog.archetypes.all.filter { $0.kind == .blood }.count == 6)
        #expect(catalog.archetypes.all.filter { $0.kind == .bone }.count == 6)
        #expect(catalog.gifts.all.filter { fromCore($0.source) }.count == 23)
        #expect(catalog.gifts.all.filter { fromCore($0.source) }.flatMap(\.facets).count == 115)
        #expect(catalog.rites.all.filter { fromCore($0.source) }.count == 23)
        #expect(catalog.fetishes.all.filter { fromCore($0.source) }.count == 18)
        #expect(catalog.tilts.all.filter { fromCore($0.source) }.map(\.name)
                == ["Arm Wrack", "Blinded", "Earthquake", "Heavy Winds", "Knocked Down", "Leg Wrack", "Poisoned", "Stunned"])
        #expect(catalog.tilts.all.filter { $0.kind == .environmental }.map(\.id) == ["earthquake", "heavy-winds"])
        // The human Merits the Werewolf book reprints, e.g. Language, are offered
        #expect(catalog.merits.entry("language")?.source.book == "wtf2e-core")
        #expect(catalog.merits.all.filter { $0.category == .werewolf && fromCore($0.source) }.count == 24)
    }

    @Test func shunnedByTheMoonHasThePure() {
        let catalog = Catalog.bundled
        let book = "night-horrors-shunned-by-the-moon"
        let pure = catalog.tribes.all.filter { $0.kind == .pure }
        #expect(pure.map(\.id) == ["fire-touched", "ivory-claws", "predator-kings"])
        #expect(pure.allSatisfy { $0.source.book == book })
        for tribe in pure {
            #expect(tribe.renown != nil)
            #expect(tribe.secondaryRenown?.count == 2)
            #expect(tribe.skills?.count == 3)
            #expect(tribe.huntersAspects?.count == 2)
            #expect(tribe.huntersAspects?.allSatisfy { catalog.conditions.entry($0.condition) != nil } == true)
            #expect(tribe.giftAffinities.count == 4)
        }
        #expect(catalog.gifts.all.filter { $0.source.book == book }.count == 5)
        #expect(catalog.rites.all.filter { $0.source.book == book }.count == 5)
        #expect(catalog.merits.all.filter { $0.source.book == book }.count == 15)
        #expect(catalog.conditions.all.filter { $0.source.book == book }.count == 8)
    }

    @Test func catalogReferencesResolve() {
        let catalog = Catalog.bundled
        for auspice in catalog.auspices.all {
            #expect(catalog.gifts.entry(auspice.moonGift)?.kind == .moon)
            #expect(auspice.giftAffinities.allSatisfy { catalog.gifts.entry($0)?.kind == .shadow })
            #expect(catalog.conditions.entry(auspice.huntersAspect.condition) != nil)
        }
        for tribe in catalog.tribes.all {
            #expect(tribe.giftAffinities.allSatisfy { catalog.gifts.entry($0)?.kind == .shadow })
            #expect((tribe.renown == nil) == (tribe.kind == .ghostWolf))
        }
        for gift in catalog.gifts.all {
            // Moon Gifts go by dots; Shadow and Wolf Gifts have one Facet per Renown
            if gift.kind == .moon {
                #expect(gift.facets.compactMap(\.dots) == [1, 2, 3, 4, 5])
            } else {
                #expect(Set(gift.facets.compactMap(\.renown)) == Set(Renown.allCases))
            }
        }
        let knownKinds: Set<Prerequisite.Kind> = [.attribute, .skill, .merit, .willpower, .other, .renown, .primalUrge,
                                                  .harmony, .tribe, .notTribe, .auspice]
        for merit in catalog.merits.all {
            for prerequisite in merit.prerequisites + merit.prerequisitesAnyOf.flatMap({ $0 }) {
                #expect(knownKinds.contains(prerequisite.kind), "\(merit.id): \(prerequisite.kind.rawValue)")
                if prerequisite.kind == .merit {
                    #expect(catalog.merits.entry(prerequisite.id ?? "") != nil)
                }
                if prerequisite.kind == .tribe || prerequisite.kind == .notTribe {
                    #expect(catalog.tribes.entry(prerequisite.id ?? "") != nil)
                }
            }
        }
    }

    @Test func healthIsStaminaPlusSize() {
        let character = ForsakenCharacter()
        character.attributes.first { $0.kind == .stamina }?.rating = 3
        #expect(character.health == 8)
        #expect(character.healthBoxes.count == 8)
    }

    @Test func xpModeChargesAndRefunds() {
        let character = ForsakenCharacter()
        character.xpMode = true
        character.experiences = 10
        let strength = character.attributes.first { $0.kind == .strength }!

        var before = character.traitSnapshot
        strength.rating = 3
        character.recordChanges(since: before)
        #expect(character.experiencesSpent == 8)
        #expect(character.experiencesAvailable == 2)

        before = character.traitSnapshot
        strength.rating = 2
        character.recordChanges(since: before)
        #expect(character.experiencesSpent == 4)
        #expect(character.changeLog.map(\.costText) == ["Spent 8", "Refunded 4"])
    }

    @Test func resolvingAConditionGivesABeat() throws {
        let character = ForsakenCharacter()
        let entry = try #require(Catalog.bundled.conditions.all.first { $0.beatOnResolve })
        let condition = CharacterCondition(source: .catalog(entry.id))
        character.addCondition(condition)
        character.resolveCondition(condition)
        #expect(character.conditions.isEmpty)
        #expect(character.beats == 1)
    }
}

@MainActor
struct WerewolfRulesTests {
    private func facet(_ id: String) -> OwnedFacet {
        OwnedFacet(source: .catalog(id))
    }

    @Test func newCharactersStartAsTheBookSays() {
        let character = ForsakenCharacter()
        #expect(character.primalUrge == 1)
        #expect(character.essence == 7)
        #expect(character.primalUrgeLevel.essenceMaximum == 10)
        #expect(character.harmony == 7)
        #expect(character.form == .hishu)
    }

    @Test func werewolfTraitsLoadBackAsSaved() throws {
        let character = ForsakenCharacter()
        character.auspice = "Irraka"
        character.tribe = "Hunters in Darkness"
        character.blood = "Fox"
        character.lodge = "My Own Lodge"
        character.setRenown(.cunning, to: 2)
        character.primalUrge = 3
        character.essence = 9
        character.harmony = 6
        character.form = .gauru
        character.kuruthTriggers.passive = "Smelling blood"
        character.facets.append(facet("rage-incite-fury"))
        character.rites.append(OwnedRite(source: .catalog("chain-rage")))
        character.fetishes.append(OwnedFetish(source: .custom("Grandmother's Knife"), customRating: 2, note: "A blade-spirit"))

        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(loaded.auspiceSource == .catalog("irraka"))
        #expect(loaded.tribeSource == .catalog("hunters-in-darkness"))
        #expect(loaded.bloodSource == .catalog("fox"))
        #expect(loaded.lodgeSource == .custom("My Own Lodge"))
        #expect(loaded.renown(.cunning) == 2 && loaded.renown(.glory) == 0)
        #expect(loaded.primalUrge == 3 && loaded.essence == 9 && loaded.harmony == 6)
        #expect(loaded.form == .gauru)
        #expect(loaded.kuruthTriggers.passive == "Smelling blood")
        #expect(loaded.facets.map(loaded.facetName) == ["Incite Fury"])
        #expect(loaded.rites.map(loaded.riteName) == ["Chain Rage"])
        #expect(loaded.fetishes.first?.customRating == 2 && loaded.fetishes.first?.note == "A blade-spirit")
    }

    @Test func shiftingToASmallerFormKeepsItsWounds() throws {
        // The book's example (p. 172): Dalu with nine of ten boxes lethal, forced into Hishu
        let character = ForsakenCharacter()
        character.attributes.first { $0.kind == .stamina }?.rating = 3
        character.form = .dalu
        #expect(character.health == 10)
        for index in 0..<9 { character.setHealthBox(at: index, to: .lethal) }
        character.form = .hishu
        #expect(character.healthBoxes == [.aggravated] + Array(repeating: .lethal, count: 7))
        // and the wounds don't come back with the boxes
        character.form = .dalu
        #expect(character.healthBoxes.suffix(2) == [.none, .none])

        // Health lost another way, e.g. Stamina, is folded when the sheet sees it, and in any case on saving
        let other = ForsakenCharacter()
        let stamina = try #require(other.attribute(.stamina))
        stamina.rating = 3
        for index in 0..<8 { other.setHealthBox(at: index, to: .bashing) }
        stamina.rating = 1
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(other))
        #expect(loaded.healthBoxes == [.lethal, .lethal, .bashing, .bashing, .bashing, .bashing])
    }

    @Test func untrainedBrawlTakesADieOff() throws {
        let character = ForsakenCharacter()
        character.attributes.first { $0.kind == .strength }?.rating = 3
        #expect(character.brawlPool(in: .hishu) == 2)
        try #require(character.skill(.brawl)).rating = 1
        #expect(character.brawlPool(in: .hishu) == 4)
    }

    @Test func aTotemCantGrantTotemOrDedicatedLocus() {
        #expect(Totem.meritsNeverGranted.allSatisfy { Catalog.bundled.merits.entry($0) != nil })
        #expect(Totem.meritsNeverGranted == ["dedicated-locus", "totem"])
    }

    @Test func formsChangeAttributesSizeAndHealth() {
        let character = ForsakenCharacter()
        let strength = character.attributes.first { $0.kind == .strength }!
        strength.rating = 2
        character.attributes.first { $0.kind == .stamina }?.rating = 2
        #expect(character.health == 7)
        character.form = .gauru
        #expect(character.totalAttributeRating(for: strength) == 5)
        #expect(character.attributeNote(for: .strength) == "+3 in Gauru")
        // Stamina 2 + 2, Size 5 + 2
        #expect(character.health == 11)
        character.form = .urhan
        #expect(character.effectiveSize == 4)
    }

    @Test func primalUrgeSetsTheTraitMaximum() {
        let character = ForsakenCharacter()
        #expect(character.baseRatingCap == 5)
        character.primalUrge = 7
        #expect(character.baseRatingCap == 7)
        #expect(character.primalUrgeLevel.essenceMaximum == 25)
    }

    @Test func facetsCostAsTheBookSays() {
        let character = ForsakenCharacter()
        character.auspice = "Irraka"
        character.tribe = "Blood Talons"
        let own = facet("new-moon-eviscerate"), wolf = facet("hunting-honed-senses")
        let affinity = facet("rage-incite-fury"), other = facet("death-cold-embrace")
        character.facets = [own, wolf, affinity, other]
        let cost = { (facet: OwnedFacet) in character.experienceCost(of: TraitKey(.facet, facet.id.uuidString), level: 1) }
        #expect(cost(own) == 0)
        #expect(cost(wolf) == 1)
        #expect(cost(affinity) == 3)
        #expect(cost(other) == 5)
        let second = facet("rage-berserkers-might")
        character.facets.append(second)
        #expect(cost(second) == 2)
        #expect(character.experienceCost(of: TraitKey(.renown, "glory"), level: 1) == 3)
        #expect(character.experienceCost(of: TraitKey(.primalUrge, "primalUrge"), level: 2) == 5)
    }

    @Test func thePureHaveNoAuspice() {
        let character = ForsakenCharacter()
        character.auspice = "Irraka"
        character.tribe = "Predator Kings"
        #expect(character.isPure)
        #expect(character.effectiveAuspice == nil)
        // Their affinities are the tribe's alone, and no Moon Gift comes free
        #expect(character.affinityGifts == ["hunger", "nature", "rage", "strength"])
        let moon = facet("new-moon-eviscerate")
        character.facets = [moon]
        #expect(character.experienceCost(of: TraitKey(.facet, moon.id.uuidString), level: 1) == 5)
        #expect(character.huntersAspect == nil)
        character.pureHuntersAspect = "Primal"
        #expect(character.huntersAspect?.condition == "instinctive")
        #expect(character.summary().listDetails == ["", "Predator Kings"])
    }

    @Test func moonGiftFacetsComeWithAuspiceRenown() throws {
        let character = ForsakenCharacter()
        character.auspice = "Cahalith"
        #expect(character.moonGift?.id == "gibbous-moon")
        #expect(character.moonGiftDots == 0)
        character.setRenown(.glory, to: 2)
        #expect(character.moonGiftDots == 2)
        // An alternate Moon Gift uses the same Renown
        character.moonGiftSource = .catalog("screaming-moon")
        #expect(character.moonGift?.name == "Gift of the Screaming Moon")
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(loaded.moonGift?.id == "screaming-moon")
        #expect(loaded.moonGiftDots == 2)
        // The Pure have none
        character.tribe = "Fire-Touched"
        #expect(character.moonGift == nil)
        #expect(character.moonGiftDots == 0)
        #expect(!character.sheetSections.contains(.moonGifts))
    }

    @Test func customMoonGiftKeepsItsFacetNames() throws {
        let character = ForsakenCharacter()
        character.moonGiftSource = .custom("Gift of the Blood Moon")
        character.customMoonFacets = ["War Howl", "Battle Plan"]
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(loaded.moonGiftName == "Gift of the Blood Moon")
        #expect(loaded.customMoonFacets == ["War Howl", "Battle Plan"])
    }

    @Test func savedMoonGiftFacetsAreDropped() throws {
        let data = Data(#"{"game": "forsaken", "schemaVersion": 1, "facets": [{"source": {"catalog": "new-moon-eviscerate"}}, {"source": {"catalog": "hunting-honed-senses"}}]}"#.utf8)
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: data)
        #expect(loaded.facets.compactMap(\.source.catalogID) == ["hunting-honed-senses"])
    }

    @Test func customFacetsKeepTheirKindOfGift() throws {
        let character = ForsakenCharacter()
        character.facets = [OwnedFacet(source: .custom("Howl of Ages"), customGift: "Gift of Time", customKind: .wolf)]
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(loaded.facets.first?.customKind == .wolf)
    }

    @Test func unofficialContentIsMarkedAndOptional() throws {
        let catalog = Catalog.bundled
        let unofficial = catalog.books.filter { !$0.official }
        #expect(unofficial.map(\.id) == ["giver-of-gifts-1", "giver-of-gifts-2"])
        #expect(catalog.books.hasUnofficial)
        #expect(catalog.books.visible(includingUnofficial: false).allSatisfy { $0.official })
        #expect(catalog.gifts.entry("screaming-moon")?.auspice == "cahalith")
        #expect(catalog.gifts.entry("cities")?.kind == .shadow)
        #expect(catalog.gifts.entry("essence")?.kind == .wolf)
        #expect(catalog.gifts.entry("screaming-moon")?.source.citation() == "https://theonyxpath.com/the-giver-of-gifts-1-werewolf-the-forsaken")
        let character = ForsakenCharacter()
        #expect(!character.showsUnofficialContent)
        character.showsUnofficialContent = true
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(loaded.showsUnofficialContent)
    }

    @Test func humanMeritsAreUnavailable() throws {
        let merit = try #require(Catalog.bundled.merits.entry("apocalypsis-fidei"))
        #expect(ForsakenCharacter().meritUnavailableReason(merit) != nil)
        #expect(Catalog.bundled.conditions.entry("enraptured") != nil)
    }

    @Test func kuruthTriggersComeFromTheChosenSet() throws {
        let character = ForsakenCharacter()
        character.kuruthTriggerSource = .catalog("blood")
        #expect(character.kuruthTrigger(.common) == "Tasting human blood.")
        #expect(Catalog.bundled.kuruthTriggers.all.map(\.name) == ["Blood", "Moon", "The Other", "Pack", "Territory", "Wounds"])
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(loaded.kuruthTriggerSet?.id == "blood")
    }

    @Test func harmonySetsWhichTriggersApply() {
        let applying = { (harmony: Int) in KuruthTriggers.Kind.allCases.filter { $0.applies(atHarmony: harmony) } }
        #expect(applying(0) == [.passive, .common, .specific])
        #expect(applying(10) == [.passive, .common, .specific])
        #expect(applying(1) == [.common, .specific])
        #expect(applying(9) == [.common, .specific])
        #expect(applying(3) == [.specific])
        #expect(applying(7) == [.specific])
        #expect(applying(5).isEmpty)
    }

    @Test func auspiceBenefitIsShownExceptForThePure() {
        let character = ForsakenCharacter()
        #expect(character.auspiceBenefit == nil)
        character.auspice = "Rahu"
        #expect(character.auspiceBenefit?.1.name == "Tenacious")
        #expect(character.sheetSections.contains(.auspiceBenefit))
        #expect(Catalog.bundled.auspices.all.allSatisfy { $0.benefit != nil })
        character.tribe = "Ivory Claws"
        #expect(character.auspiceBenefit == nil)
        #expect(!character.sheetSections.contains(.auspiceBenefit))
    }

    @Test func siskurDahListsTheOtherFactionApart() throws {
        let entry = try #require(Catalog.bundled.conditions.entry("siskur-dah"))
        let forsaken = ForsakenCharacter()
        let groups = forsaken.noteOptionGroups(for: entry)
        #expect(groups.map(\.title) == ["Forsaken Tribes", "Lodges", "Pure Tribes"])
        #expect(groups[0].options.count == 5 && groups[0].warning == nil)
        // A ritemaster may give their lodge's Sacred Hunt in place of their tribe's (The Pack, p. 80)
        #expect(groups[1].options.count == 5 && groups[1].warning == nil)
        #expect(groups[2].options.map(\.name) == ["Fire-Touched", "Ivory Claws", "Predator Kings"])
        #expect(groups[2].warning != nil)
        // Bale Hounds and the Urighur are in the catalog but not offered
        #expect(entry.noteOption(named: "Urighur") != nil)
        #expect(!groups.flatMap(\.options).contains { $0.name == "Urighur" })
        #expect(entry.noteOption(named: "Storm Lords")?.summary.isEmpty == false)
        let pure = ForsakenCharacter()
        pure.tribe = "Predator Kings"
#expect(pure.noteOptionGroups(for: entry).map(\.title) == ["Pure Tribes", "Lodges", "Forsaken Tribes"])
    }

    @Test func derivedTraitsFollowTheForm() throws {
        let character = ForsakenCharacter()
        for (kind, rating) in [(AttributeKind.strength, 2), (.dexterity, 3), (.wits, 2), (.composure, 2)] {
            character.attributes.first { $0.kind == kind }?.rating = rating
        }
        character.skills.first { $0.skillID == .athletics }?.rating = 2
        #expect(character.size(in: .hishu) == 5)
        #expect(character.defense(in: .hishu) == 4)
        #expect(character.initiative(in: .hishu) == 5)
        #expect(character.speed(in: .hishu) == 10)
        // Gauru: Strength +3, Dexterity +1, Size +2 (Speed +4, Initiative +1)
        #expect(character.size(in: .gauru) == 7)
        #expect(character.speed(in: .gauru) == 14)
        #expect(character.initiative(in: .gauru) == 6)
        // Urhan: Dexterity +2, Size −1, and the wolf's species factor (Speed +5, Initiative +2)
        #expect(character.size(in: .urhan) == 4)
        #expect(character.speed(in: .urhan) == 15)
        #expect(character.initiative(in: .urhan) == 7)
        character.armor = 2
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(loaded.armor == 2)
    }

    @Test func bonusDotsPastTheLimitStackBySource() throws {
        // The user's ruling: each source lets a trait go one past the maximum, and sources stack; a totem counts once
        let character = ForsakenCharacter()
        let strength = try #require(character.attribute(.strength))
        strength.rating = 5
        character.totem.advantages = [TotemAdvantage(kind: .attribute, target: "strength", dots: 2)]
        #expect(character.totalAttributeRating(for: strength) == 7)
        #expect(character.countedAttributeRating(for: strength) == 6)
        character.merits.append(Merit(source: .catalog("embodiment-of-the-firstborn"), qualifier: "Strength", rating: 5))
        #expect(character.totalAttributeRating(for: strength) == 8)
        #expect(character.countedAttributeRating(for: strength) == 7)
        character.primalUrge = 6
        #expect(character.countedAttributeRating(for: strength) == 8)
        strength.rating = 6
        #expect(character.totalAttributeRating(for: strength) == 9)
        #expect(character.countedAttributeRating(for: strength) == 8)
        // The form's changes come on top
        character.form = .gauru
        #expect(character.countedAttributeRating(for: strength) == 11)
    }

    @Test func totemAdvantagesCostExperiencesFromThePacksPoints() throws {
        var totem = Totem()
        #expect(totem.experienceBudget == 0)
        for (points, budget) in [(1, 1), (8, 1), (9, 3), (14, 3), (15, 5), (20, 5), (21, 10)] {
            totem.packPoints = points
            #expect(totem.experienceBudget == budget)
        }
        totem.advantages = [TotemAdvantage(kind: .attribute, target: "strength"),
                            TotemAdvantage(kind: .merit, target: "fleet-of-foot")]
        #expect(totem.experiencesSpent == 5)
        let character = ForsakenCharacter()
        character.totem = totem
        character.totem.advantages.append(TotemAdvantage(kind: .skill, target: "brawl"))
        character.totem.advantages.append(TotemAdvantage(kind: .specialty, target: "brawl", detail: "Claws"))
        let brawl = try #require(character.skill(.brawl))
        brawl.rating = 5
        #expect(character.countedSkillRating(for: brawl) == 6)
        #expect(character.grantedSpecialties(for: brawl) == ["Claws"])
        // The totem's Strength dot and Fleet of Foot both add to Speed
        #expect(character.speed(in: .hishu) == (1 + 1) + 1 + 5 + 1)
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(loaded.totem == character.totem)
    }

    @Test func pureHuntersAspectLoadsBackAsSaved() throws {
        let character = ForsakenCharacter()
        character.tribe = "Fire-Touched"
        character.pureHuntersAspect = "Frenzied"
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(loaded.isPure)
        #expect(loaded.huntersAspect?.condition == "frantic")
    }

    @Test func werewolfMeritPrerequisitesAreChecked() throws {
        let character = ForsakenCharacter()
        let fading = try #require(Catalog.bundled.merits.entry("fading"))
        #expect(character.unmetPrerequisites(for: fading).map(\.description) == ["Cunning 2"])
        character.setRenown(.cunning, to: 2)
        #expect(character.unmetPrerequisites(for: fading).isEmpty)

        let embodiment = try #require(Catalog.bundled.merits.entry("embodiment-of-the-firstborn"))
        character.tribe = "Ghost Wolves"
        #expect(character.unmetPrerequisites(for: embodiment).count == 1)
    }
}

@MainActor
struct ForsakenCreationTests {
    private func facet(_ id: String) -> OwnedFacet {
        OwnedFacet(source: .catalog(id))
    }

    /// A Rahu Blood Talon with Purity and Glory.
    private func rahu(tribe: String = "Blood Talons") -> ForsakenCharacter {
        let character = ForsakenCharacter.guided()
        character.auspice = "Rahu"
        character.tribe = tribe
        return character
    }

    @Test func guidedCharactersStartWithTheFreeMerits() throws {
        let character = ForsakenCharacter.guided()
        #expect(character.isInCreation)
        #expect(character.merits.map(\.name) == ["Totem", "Language (First Tongue)"])
        #expect(character.creationReport.merits.used == 0)
        #expect(character.creationReport.isWithinLimits)
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(loaded.isInCreation)
    }

    @Test func renownFollowsTheTribe() {
        let forsaken = rahu()
        #expect(forsaken.creationReport.renown.allowed == 3)
        forsaken.setRenown(.purity, to: 1)
        forsaken.setRenown(.glory, to: 1)
        forsaken.setRenown(.honor, to: 1)
        #expect(forsaken.creationReport.isWithinLimits)
        // No Renown above two at creation
        #expect(forsaken.editableMaximum(for: TraitKey(.renown, "glory"), upTo: 5) == 1)

        // Ghost Wolves have no tribal Renown, so one fewer dot
        let ghost = rahu(tribe: "Ghost Wolves")
        #expect(ghost.creationReport.renown.allowed == 2)
        ghost.setRenown(.honor, to: 2)
        #expect(ghost.creationReport.problems.contains(.renownMissing("Rahu Renown (Purity)")))

        // The Pure: the primary Renown, and a dot in it or a secondary one
        let pure = rahu(tribe: "Predator Kings")
        #expect(pure.creationReport.renown.allowed == 2)
        pure.setRenown(.glory, to: 1)
        pure.setRenown(.cunning, to: 1)
        #expect(pure.creationReport.problems.contains(.pureRenownElsewhere))
    }

    @Test func shadowFacetsComeFromTheTribeAndAuspice() {
        let character = rahu()
        character.setRenown(.purity, to: 1)
        character.setRenown(.glory, to: 2)
        // Rage is the Blood Talons', Dominance the Rahu's
        character.facets = [facet("rage-berserkers-might"), facet("dominance-snarl-of-the-predator")]
        #expect(character.creationReport.isWithinLimits)
        #expect(!character.creationAllows(.facet(Catalog.bundled.facet("death-barghest")!.facet, gift: Catalog.bundled.gifts.entry("death")!)))

        // Ghost Wolves only have the auspice's
        let ghost = rahu(tribe: "Ghost Wolves")
        ghost.setRenown(.glory, to: 1)
        ghost.facets = [facet("rage-berserkers-might")]
        #expect(ghost.creationReport.problems.contains(.shadowFacetOutsideAffinities))
        ghost.facets = [facet("dominance-glorious-lunacy")]
        #expect(ghost.creationReport.isWithinLimits)
        // and start with one Shadow Gift (p. 50)
        #expect(ghost.creationReport.shadowFacets.allowed == 1)
        ghost.facets = [facet("dominance-glorious-lunacy"), facet("strength-predators-unmatched-pursuit")]
        #expect(ghost.creationReport.problems.contains(.tooManyShadowFacets(allowed: 1)))
    }

    @Test func ghostWolvesCantStartWithTheSecondMoonFacet() {
        let ghost = rahu(tribe: "Ghost Wolves")
        ghost.applyCreationGrants()
        #expect(ghost.renown(.purity) == 1)
        // The other dot can't go on the auspice's Renown, which would bring the Facet (p. 50)
        #expect(ghost.editableMaximum(for: TraitKey(.renown, "purity"), upTo: 5) == 1)
        #expect(ghost.editableMaximum(for: TraitKey(.renown, "glory"), upTo: 5) == 1)
        ghost.setRenown(.purity, to: 2)
        #expect(ghost.creationReport.problems.contains(.ghostWolfMoonGift(renown: "Purity")))
        // A tribe's werewolf may
        let forsaken = rahu()
        forsaken.applyCreationGrants()
        #expect(forsaken.editableMaximum(for: TraitKey(.renown, "purity"), upTo: 5) == 2)
    }

    @Test func theTwoShadowFacetsComeFromDifferentGifts() throws {
        let character = rahu()
        character.setRenown(.purity, to: 1)
        character.setRenown(.glory, to: 2)
        character.facets = [facet("dominance-snarl-of-the-predator")]
        let second = try #require(Catalog.bundled.facet("dominance-glorious-lunacy"))
        #expect(!character.creationAllows(.facet(second.facet, gift: second.gift)))
        character.facets.append(facet("dominance-glorious-lunacy"))
        #expect(character.creationReport.problems == [.shadowFacetsFromOneGift])
        // The Pure's two tribe Facets may share a Gift (Shunned by the Moon, p. 202)
        let pure = rahu(tribe: "Predator Kings")
        pure.setRenown(.glory, to: 1)
        pure.setRenown(.purity, to: 1)
        pure.facets = [facet("rage-berserkers-might"), facet("rage-slaughterer")]
        #expect(!pure.creationReport.problems.contains(.shadowFacetsFromOneGift))
    }

    @Test func aWolfFacetUnlessTwoDotsOfAuspiceRenown() {
        let character = rahu()
        character.setRenown(.cunning, to: 1)
        character.facets = [facet("hunting-honed-senses")]
        #expect(character.creationReport.wolfFacets.allowed == 1)
        #expect(character.creationReport.isWithinLimits)
        character.setRenown(.purity, to: 2)
        #expect(character.creationReport.problems.contains(.tooManyWolfFacets(allowed: 0)))
    }

    @Test func thePureTakeThreeShadowFacetsAndAWolfFacet() {
        let pure = rahu(tribe: "Predator Kings")
        pure.setRenown(.glory, to: 1)
        pure.setRenown(.purity, to: 1)
        // Two of the tribe's (Rage, Strength) and one of any (Dominance)
        pure.facets = [facet("rage-berserkers-might"), facet("strength-predators-unmatched-pursuit"),
                       facet("dominance-snarl-of-the-predator"), facet("hunting-cow-the-prey")]
        #expect(pure.creationReport.shadowFacets.allowed == 3)
        #expect(pure.creationReport.isWithinLimits)
        #expect(pure.freeTotemDots == 2)
    }

    @Test func meritDotsPayForPrimalUrgeAndExtraRites() {
        let character = rahu()
        character.primalUrge = 2
        #expect(character.creationReport.merits.used == 5)
        character.rites = [OwnedRite(source: .custom("Rite of One"), customRating: 3)]
        #expect(character.creationReport.merits.used == 6)
        #expect(character.editableMaximum(for: TraitKey(.primalUrge, "primalUrge"), upTo: 10) == 2)
        character.primalUrge = 1
        #expect(character.editableMaximum(for: TraitKey(.primalUrge, "primalUrge"), upTo: 10) == 2)
    }

    @Test func auspiceAndTribeGiveTheirRenownDots() {
        let character = rahu()
        character.applyCreationGrants()
        #expect(character.renown(.purity) == 1)
        #expect(character.renown(.glory) == 1)
        #expect(character.grantedRenownDots(.purity) == 1)
        // A new tribe moves its dot
        character.tribe = "Storm Lords"
        character.applyCreationGrants()
        #expect(character.renown(.glory) == 0)
        #expect(character.renown(.honor) == 1)
        // Ghost Wolves have none; the Pure have the tribe's and no auspice's, and two Totem dots
        character.tribe = "Ghost Wolves"
        character.applyCreationGrants()
        #expect(character.creationReport.renown.used == 1)
        character.tribe = "Predator Kings"
        character.applyCreationGrants()
        #expect(character.renown(.purity) == 0)
        #expect(character.renown(.glory) == 1)
        #expect(character.merits.first { $0.source == .catalog("totem") }?.rating == 2)
    }

    @Test func aNewAuspiceTakesBackTheFreeSkillDot() throws {
        let character = rahu()
        character.chooseFreeSkill(.brawl)
        character.auspice = "Cahalith"
        character.applyCreationGrants()
        #expect(try #require(character.skill(.brawl)).rating == 0)
        #expect(character.needsFreeSkill)
    }

    @Test func totemMeritsGetARowAndIgnorePrerequisites() throws {
        let character = rahu()
        let previous = character.totem.advantages
        character.totem.advantages = [TotemAdvantage(kind: .merit, target: "fleet-of-foot", dots: 2)]
        character.syncTotemMerits(previous: previous)
        let merit = try #require(character.merits.first { $0.source == .catalog("fleet-of-foot") })
        #expect(merit.rating == 0)
        #expect(character.meritBonus(for: "fleet-of-foot") == 2)
        #expect(!character.prerequisitesApply(to: merit))
        #expect(character.creationReport.isWithinLimits)
        // Bought dots add to the totem's
        merit.rating = 1
        #expect(character.speed(in: .hishu) == 1 + 1 + 5 + 3)
        merit.rating = 0
        let granted = character.totem.advantages
        character.totem.advantages = []
        character.syncTotemMerits(previous: granted)
        #expect(!character.merits.contains { $0.source == .catalog("fleet-of-foot") })
    }

    @Test func theFreeSkillDotIsOutsideThePriorities() throws {
        let character = rahu()
        character.setPriority(.primary, for: .physical, skills: true)
        character.chooseFreeSkill(.brawl)
        let brawl = try #require(character.skill(.brawl))
        #expect(brawl.rating == 1)
        #expect(character.creationReport.skills[.physical]?.used == 0)
        #expect(!character.needsFreeSkill)
        character.finishCreation(bonusExperiences: 5)
        #expect(!character.isInCreation)
        #expect(character.experiences == 5)
        #expect(character.xpMode)
    }
}

@MainActor
struct GiftEffectTests {
    @Test func passiveGiftsChangeDerivedTraits() throws {
        let character = ForsakenCharacter()
        character.auspice = "Rahu"
        character.setRenown(.purity, to: 2)
        // Warrior's Hide is the Full Moon's second dot: Purity to Health
        let stamina = try #require(character.attribute(.stamina))
        #expect(character.health == stamina.rating + 5 + 2)
        // Rabid Fever: Purity to Initiative; Zeal: Purity to Willpower; Primeval Echo: Purity to the Essence maximum
        let initiative = character.initiative(in: .hishu)
        character.facets = [OwnedFacet(source: .catalog("disease-rabid-fever")), OwnedFacet(source: .catalog("fervor-zeal")),
                            OwnedFacet(source: .catalog("essence-primeval-echo"))]
        #expect(character.initiative(in: .hishu) == initiative + 2)
        #expect(character.willpower == character.rating(of: .resolve) + character.rating(of: .composure) + 2)
        #expect(character.essenceMaximum == character.primalUrgeLevel.essenceMaximum + 2)
    }

    @Test func activePowersAreSwitchedOn() throws {
        let character = ForsakenCharacter()
        character.setRenown(.purity, to: 3)
        let strength = try #require(character.attribute(.strength))
        strength.rating = 5
        let primal = OwnedFacet(source: .catalog("strength-primal-strength"))
        character.facets = [primal]
        #expect(character.totalAttributeRating(for: strength) == 5)
        primal.isActive = true
        // Purity 3 to Strength, past the usual maximum, and into the Brawl pool (a die off with no Brawl)
        #expect(character.totalAttributeRating(for: strength) == 8)
        #expect(character.countedAttributeRating(for: strength) == 8)
        #expect(character.brawlPool(in: .hishu) == 7)
        // Predator's Unmatched Pursuit only adds to Speed in Urshul and Urhan
        character.setRenown(.glory, to: 2)
        let pursuit = OwnedFacet(source: .catalog("strength-predators-unmatched-pursuit"))
        pursuit.isActive = true
        let hishu = character.speed(in: .hishu), urhan = character.speed(in: .urhan)
        character.facets.append(pursuit)
        #expect(character.speed(in: .hishu) == hishu)
        #expect(character.speed(in: .urhan) == urhan + 2)
        // Totemic Empowerment: +1 Strength, Dexterity and Stamina and 5 more Essence while it lasts
        let rite = OwnedRite(source: .catalog("totemic-empowerment"))
        rite.isActive = true
        let essence = character.essenceMaximum
        character.rites = [rite]
        #expect(character.rating(.dexterity, in: .hishu) == 2)
        #expect(character.essenceMaximum == essence + 5)
        let loaded = try JSONDecoder().decode(ForsakenCharacter.self, from: JSONEncoder().encode(character))
        #expect(loaded.facets.first?.isActive == true)
        #expect(loaded.rites.first?.isActive == true)
    }

    @Test func fortifiedFormArmorsItsForm() {
        let character = ForsakenCharacter()
        character.armor = 1
        character.merits = [Merit(source: .catalog("fortified-form"), qualifier: "Gauru", rating: 4)]
        #expect(character.armor(in: .hishu) == (1, 0))
        #expect(character.armor(in: .gauru) == (2, 1))
    }

    @Test func weaponsOnlyInFormsWithHands() throws {
        let character = ForsakenCharacter()
        try #require(character.skill(.weaponry)).rating = 2
        // Dalu adds a dot of Strength
        #expect(character.weaponryPool(in: .dalu) == 4)
        #expect(character.weaponryPool(in: .gauru) == nil)
        #expect(character.firearmsPool(in: .hishu) == 1)
    }

    @Test func newRenownBringsAFreeFacet() throws {
        let character = ForsakenCharacter()
        character.xpMode = true
        character.experiences = 10
        character.facets = [OwnedFacet(source: .catalog("dominance-primal-allure"))]
        character.setRenown(.purity, to: 1)
        #expect(character.renownFacetCredits[.purity] == 1)
        let found = try #require(Catalog.bundled.facet("dominance-snarl-of-the-predator"))
        #expect(character.canLearnFree(found.facet, of: found.gift))
        // Not in a Gift the character hasn't unlocked
        let other = try #require(Catalog.bundled.facet("death-bone-gnaw"))
        #expect(!character.canLearnFree(other.facet, of: other.gift))
        character.learn(found.facet, of: found.gift)
        let learned = try #require(character.facets.last)
        #expect(learned.learnedWithRenown)
        #expect(character.experienceCost(of: TraitKey(.facet, learned.id.uuidString), level: 1) == 0)
        #expect(character.renownFacetCredits[.purity] == 0)
        character.forget(learned)
        #expect(character.renownFacetCredits[.purity] == 1)
    }

    @Test func chroniclesCoreMeritsMissingFromTheWerewolfBookAreThere() {
        for id in ["mystery-cult-initiation", "library", "true-friend", "trained-observer"] {
            #expect(Catalog.bundled.merits.entry(id)?.source.book == "cofd-core", "\(id)")
        }
    }
}

@MainActor
struct ThePackTests {
    private let catalog = Catalog.bundled
    private let fromThePack = { (source: SourceReference) in source.book == "the-pack" }

    @Test func thePackHasItsLodgesAndTheirLore() throws {
        let lodges = catalog.lodges.all.filter { fromThePack($0.source) }
        #expect(lodges.map(\.name) == ["Lodge of Garm", "The Thousand Steel Teeth", "Lodge of the Screaming Moon",
                                       "The Temple of Apollo", "The Eaters of the Dead"])
        // Each marks its adherents three ways, has its own Sacred Hunt, and teaches things that are in the catalog
        for lodge in lodges {
            #expect(lodge.hasRules && lodge.marks.map(\.label) == ["Blessing", "Aspiration", "Ban"], "\(lodge.name)")
            #expect(lodge.sacredHunt?.name == lodge.name, "\(lodge.name)")
            #expect(lodge.lore.count == (lodge.merits ?? []).count + (lodge.rites ?? []).count + (lodge.fetishes ?? []).count)
            #expect(!lodge.lore.isEmpty, "\(lodge.name)")
        }
        // The core book's Eaters of the Dead stay, as a story-only lodge under their own book
        let core = try #require(catalog.lodges.entry("eaters-of-the-dead"))
        #expect(!core.hasRules && core.source.book == "wtf2e-core")
        #expect(catalog.merits.all.filter { fromThePack($0.source) }.count == 6)
        #expect(catalog.rites.all.filter { fromThePack($0.source) }.map(\.name) == ["Banshee Howl", "Carrion Feast"])
        #expect(catalog.fetishes.all.filter { fromThePack($0.source) }.count == 5)
        #expect(catalog.tilts.entry("essence-bleed") != nil)
        // Every Merit and rite of the book belongs to a lodge
        #expect(catalog.merits.all.filter { fromThePack($0.source) }.allSatisfy { !catalog.lodges(teachingMerit: $0.id).isEmpty })
        #expect(catalog.lodges(teachingMerit: "lodge-sorcery").count == 3)
        let style = try #require(catalog.merits.entry("uma-suguthkuth"))
        #expect(style.styleManeuvers.count == 5 && style.category == .fighting)
    }

    @Test func aLodgeWithRulesGetsItsSection() {
        let character = ForsakenCharacter()
        #expect(!character.sheetSections.contains(.lodge))
        character.lodgeSource = .catalog("eaters-of-the-dead")
        #expect(character.lodgeWithRules == nil && !character.sheetSections.contains(.lodge))
        character.lodgeSource = .catalog("the-pack-eaters-of-the-dead")
        #expect(character.lodgeWithRules?.blessing != nil && character.sheetSections.contains(.lodge))
    }

    @Test func lodgeMeritsAskForTheLodge() throws {
        let character = ForsakenCharacter()
        let sorcery = try #require(catalog.merits.entry("lodge-sorcery"))
        #expect(character.unmetPrerequisites(for: sorcery).map(\.description) == [
            "Lodge: Lodge of the Screaming Moon, The Temple of Apollo or The Eaters of the Dead (three times the cost otherwise)"])
        character.lodgeSource = .catalog("temple-of-apollo")
        #expect(character.unmetPrerequisites(for: sorcery).isEmpty)
        // A Merit no lodge teaches asks for none
        #expect(character.prerequisiteChecks(for: try #require(catalog.merits.entry("fast-reflexes"))).allSatisfy { !$0.description.hasPrefix("Lodge") })
    }

    @Test func lodgeLoreCostsOutsidersThreeTimesAsMuch() throws {
        let character = ForsakenCharacter()
        character.xpMode = true
        character.experiences = 40

        // An outsider pays 3 a dot for a lodge's Merit, and 3 a dot for its rite
        var before = character.traitSnapshot
        let armory = Merit(source: .catalog("lodge-armory"), rating: 3)
        character.merits.append(armory)
        character.rites.append(OwnedRite(source: .catalog("banshee-howl")))
        character.recordChanges(since: before)
        #expect(character.changeLog.map(\.experiences) == [9, 9])

        // Lowering the Merit gives back what was paid, even after joining
        character.lodgeSource = .catalog("garm")
        before = character.traitSnapshot
        character.merits.removeAll { $0.id == armory.id }
        character.recordChanges(since: before)
        #expect(character.changeLog.last?.experiences == -9)

        // An adherent pays the usual cost: 1 a dot. Another lodge's rite is still dear
        before = character.traitSnapshot
        character.merits.append(Merit(source: .catalog("lodge-armory"), rating: 5))
        character.rites.append(OwnedRite(source: .catalog("carrion-feast")))
        character.recordChanges(since: before)
        #expect(character.changeLog.suffix(2).map(\.experiences) == [5, 9])

        // A Merit that isn't lodge lore costs what it always did
        before = character.traitSnapshot
        character.merits.append(Merit(source: .catalog("fast-reflexes"), rating: 2))
        character.recordChanges(since: before)
        #expect(character.changeLog.last?.experiences == 2)
    }
}

@MainActor
struct SectionHeadingTests {
    /// Flat Earth Scribe can't ship in the app, so every heading needs its picture from
    /// scripts/render-forsaken-headings.swift.
    @Test func everySectionHeadingHasItsPicture() {
        let blank = ForsakenCharacter()
        let rahu = ForsakenCharacter.guided()
        rahu.auspice = "Rahu"
        let pure = ForsakenCharacter.guided()
        pure.tribe = "Fire-Touched"
        let adherent = ForsakenCharacter()
        adherent.lodgeSource = .catalog("garm")
        let sections = Set([blank, rahu, pure, adherent].flatMap(\.sheetSections))
        for section in sections {
            #expect(UIImage(named: "Heading " + section.heading) != nil, "\(section.heading)")
        }
    }
}
