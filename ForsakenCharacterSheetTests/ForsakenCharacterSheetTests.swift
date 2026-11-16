//
//  ForsakenCharacterSheetTests.swift
//  ForsakenCharacterSheetTests
//

import Foundation
import Testing
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
        #expect(Catalog.bundled.books.map(\.id) == ["wtf2e-core", "cofd-core", "night-horrors-shunned-by-the-moon", "giver-of-gifts-1", "giver-of-gifts-2"])
    }

    @Test func werewolfCoreBookIsLoaded() {
        let catalog = Catalog.bundled
        let fromCore = { (source: SourceReference) in source.book == "wtf2e-core" }
        #expect(catalog.auspices.all.count == 5)
        #expect(catalog.tribes.all.filter { fromCore($0.source) }.count == 6)
        #expect(catalog.lodges.all.count == 8)
        #expect(catalog.archetypes.all.filter { $0.kind == .blood }.count == 6)
        #expect(catalog.archetypes.all.filter { $0.kind == .bone }.count == 6)
        #expect(catalog.gifts.all.filter { fromCore($0.source) }.count == 23)
        #expect(catalog.gifts.all.filter { fromCore($0.source) }.flatMap(\.facets).count == 115)
        #expect(catalog.rites.all.filter { fromCore($0.source) }.count == 23)
        #expect(catalog.fetishes.all.count == 18)
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
