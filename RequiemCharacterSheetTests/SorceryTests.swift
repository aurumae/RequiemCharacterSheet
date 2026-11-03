//
//  SorceryTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// Blood sorcery, Devotions, Coils and Scales: the catalog data is consistent, and characters save them.
@MainActor
struct SorceryTests {
    private let catalog = Catalog.bundled

    // MARK: - Catalog data

    @Test func ritualDisciplinesBelongToTheirCovenants() throws {
        let cruac = try #require(catalog.disciplines.entry("cruac"))
        #expect(cruac.kind == .ritual)
        #expect(cruac.ritualRules?.covenant == "circle-of-the-crone")
        #expect(cruac.ritualRules?.humanity == .capAtTenMinusDots)

        let theban = try #require(catalog.disciplines.entry("theban-sorcery"))
        #expect(theban.kind == .ritual)
        #expect(theban.ritualRules?.covenant == "lancea-et-sanctum")
        #expect(theban.ritualRules?.humanity == .atLeastRitualDots)
        #expect(theban.ritualRules?.castingCost.willpower == .fixed(1))

        for rules in [cruac.ritualRules, theban.ritualRules].compactMap({ $0 }) {
            #expect(catalog.covenants.entry(rules.covenant) != nil)
        }
    }

    @Test func ritualsBelongToARitualDiscipline() {
        for ritual in catalog.rituals.all {
            #expect(catalog.disciplines.entry(ritual.discipline)?.kind == .ritual, "\(ritual.name)")
            #expect((1...5).contains(ritual.dots), "\(ritual.name)")
            #expect(ritual.targetSuccesses > 0, "\(ritual.name)")
        }
        #expect(catalog.rituals.all.filter { $0.discipline == "cruac" }.count == 10)
        #expect(catalog.rituals.all.filter { $0.discipline == "theban-sorcery" }.count == 9)
    }

    @Test func ritualFactsMatchTheBook() throws {
        let pangs = try #require(catalog.rituals.entry(named: "Pangs of Proserpina"))
        #expect(pangs.dots == 1)
        #expect(pangs.targetSuccesses == 6)
        #expect(pangs.contestedBy == "Composure + Blood Potency")
        #expect(pangs.source.page == 152)

        let stigmata = try #require(catalog.rituals.entry(named: "Stigmata"))
        #expect(stigmata.dots == 4)
        #expect(stigmata.resistedBy == "Stamina")
        #expect(stigmata.sacrament != nil)
    }

    @Test func devotionPrerequisitesAreDisciplines() {
        for devotion in catalog.devotions.all {
            let prerequisites = devotion.prerequisites + devotion.prerequisitesAnyOf.flatMap { $0 }
            #expect(!prerequisites.isEmpty, "\(devotion.name)")
            for prerequisite in prerequisites {
                #expect(prerequisite.kind == .discipline, "\(devotion.name)")
                #expect(prerequisite.id.flatMap { catalog.disciplines.entry($0) } != nil, "\(devotion.name)")
                #expect(prerequisite.minimum.map { (1...5).contains($0) } == true, "\(devotion.name)")
            }
            #expect(devotion.experienceCost > 0, "\(devotion.name)")
            if let discipline = devotion.dicePool?.discipline {
                #expect(catalog.disciplines.entry(discipline) != nil, "\(devotion.name)")
            }
        }
    }

    @Test func devotionFactsMatchTheBook() throws {
        let bodyOfWill = try #require(catalog.devotions.entry(named: "Body of Will"))
        #expect(bodyOfWill.prerequisites.map(\.id) == ["resilience", "vigor"])
        #expect(bodyOfWill.prerequisites.map(\.minimum) == [3, 1])
        #expect(bodyOfWill.experienceCost == 2)
        #expect(bodyOfWill.source.page == 142)

        // The book's own examples of costs that differ from half the prerequisite dots
        #expect(catalog.devotions.entry(named: "Subsume the Lesser Beast")?.experienceCost == 3)
        #expect(catalog.devotions.entry(named: "Enfeebling Aura")?.experienceCost == 3)

        // Summoning can be learned through either Dominate or Majesty
        let summoning = try #require(catalog.devotions.entry(named: "Summoning"))
        #expect(summoning.prerequisitesAnyOf.map { $0.map(\.id) } == [["dominate"], ["majesty"]])
    }

    @Test func everyCoilHasFiveTiersInOrder() {
        for mystery in catalog.mysteries.all {
            #expect(mystery.tiers.map(\.dots) == [1, 2, 3, 4, 5], "\(mystery.name)")
        }
        #expect(catalog.mysteries.entry(named: "Mystery of the Ascendant")?.tier(1)?.name == "Surmounting the Daysleep")
    }

    @Test func scalesNameRealCoilTiers() {
        for scale in catalog.scales.all {
            #expect(catalog.mysteries.entry(scale.mystery) != nil, "\(scale.name)")
            #expect(!scale.prerequisiteCoils.isEmpty, "\(scale.name)")
            for prerequisite in scale.prerequisiteCoils {
                let tier = catalog.mysteries.entry(prerequisite.mystery)?.tier(prerequisite.dots)
                #expect(tier?.id == prerequisite.tier, "\(scale.name)")
            }
        }
    }

    // MARK: - Characters

    @Test func newCharactersHaveNoSorcery() {
        let character = Character()
        #expect(character.rituals.isEmpty)
        #expect(character.devotions.isEmpty)
        #expect(character.coils.isEmpty)
        #expect(character.scales.isEmpty)
        #expect(character.mysteryEntry == nil)
    }

    @Test func sorceryIsSaved() throws {
        let original = Character()
        original.disciplines = [Discipline(name: "Crúac", rating: 2)]
        original.rituals = [
            Ritual(source: catalog.rituals.source(named: "Rigor Mortis")),
            Ritual(source: .custom("Mother's Embrace"), customDiscipline: .catalog("cruac"), customDots: 2),
        ]
        original.devotions = [
            Devotion(source: catalog.devotions.source(named: "Body of Will")),
            Devotion(source: .custom("Homebrew Gift"), customExperienceCost: 4),
        ]
        original.mystery = "Mystery of the Wyrm"
        original.coils = [Coil(mystery: original.mysterySource, rating: 2)]
        original.scales = [Scale(source: catalog.scales.source(named: "Kindred Sense Endowment"))]

        let reloaded = try JSONDecoder().decode(Character.self, from: JSONEncoder().encode(original))

        #expect(reloaded.disciplines.first?.source == .catalog("cruac"))
        #expect(reloaded.rituals.map(\.name) == ["Rigor Mortis", "Mother's Embrace"])
        #expect(reloaded.rituals.map(\.dots) == [1, 2])
        #expect(reloaded.rituals.map(\.discipline) == [.catalog("cruac"), .catalog("cruac")])
        #expect(reloaded.devotions.map(\.experienceCost) == [2, 4])
        #expect(reloaded.mysteryEntry?.id == "mystery-of-the-wyrm")
        #expect(reloaded.coils.first?.learnedTiers.map(\.name) == ["Stir the Beast", "Beast's Hunger"])
        #expect(reloaded.scales.first?.source == .catalog("kindred-sense-endowment"))
    }

    @Test func version6SavesLoadWithoutSorcery() throws {
        // Before version 7 a player could only type blood sorcery in as a custom Discipline
        let json = """
        {"schemaVersion": 6, "disciplines": [{"source": {"custom": "Theban Sorcery"}, "rating": 1}]}
        """
        let character = try JSONDecoder().decode(Character.self, from: Data(json.utf8))

        #expect(character.disciplines.first?.source == .catalog("theban-sorcery"))
        #expect(character.rituals.isEmpty)
        #expect(character.devotions.isEmpty)
        #expect(character.mysterySource == .custom(""))
        #expect(character.coils.isEmpty)
        #expect(character.scales.isEmpty)
    }

    @Test func coilRatingsAreKeptWithinFiveDots() throws {
        let json = #"{"mystery": {"catalog": "mystery-of-the-voivode"}, "rating": 9}"#
        let coil = try JSONDecoder().decode(Coil.self, from: Data(json.utf8))
        #expect(coil.rating == 5)
        #expect(coil.learnedTiers.count == 5)
    }
}
