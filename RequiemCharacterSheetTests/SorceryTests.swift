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
        // 10 each from Vampire: The Requiem, 14 each from Secrets of the Covenants, 3 each from A Thousand Years of Night,
        // and one Theban miracle from Dark Eras 2
        #expect(catalog.rituals.all.filter { $0.discipline == "cruac" }.count == 27)
        #expect(catalog.rituals.all.filter { $0.discipline == "theban-sorcery" }.count == 28)
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

        // The 2e book's pool says Auspex, a holdover from 1e; its prerequisites are Obfuscate and Dominate
        #expect(catalog.devotions.entry(named: "Touch of Deprivation")?.dicePool?.discipline == "obfuscate")
    }

    @Test func advancedVersionsAreSeparateEntries() throws {
        // Typed with a straight apostrophe, matching the catalog's curly one
        let gargoyle = try #require(catalog.devotions.entry(named: "Gargoyle's Vigilance (Advanced)"))
        #expect(gargoyle.experienceCost == 4)
        #expect(gargoyle.prerequisites.contains { $0.id == "protean" && $0.minimum == 5 })
        #expect(catalog.devotions.entry(named: "Gargoyle's Vigilance")?.experienceCost == 1)

        let blandishment = try #require(catalog.rituals.entry(named: "Blandishment of Sin (Advanced)"))
        #expect(blandishment.dots == 4)
        #expect(blandishment.targetSuccesses == 8)
        #expect(catalog.rituals.entry(named: "Blandishment of Sin")?.dots == 1)
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

    // MARK: - Rules

    private func character(disciplines: [(String, Int)], status: [(String, Int)] = []) -> Character {
        let character = Character()
        character.disciplines = disciplines.map { Discipline(name: $0.0, rating: $0.1) }
        character.merits = status.map { Merit(source: .catalog("covenant-status"), qualifier: $0.0, rating: $0.1) }
        return character
    }

    @Test func ritualsAboveTheDisciplineAreFlagged() {
        let character = character(disciplines: [("Crúac", 1)])
        let cheval = Ritual(source: catalog.rituals.source(named: "Cheval"))
        let rigorMortis = Ritual(source: catalog.rituals.source(named: "Rigor Mortis"))

        #expect(character.warnings(for: cheval) == ["Requires Crúac 2"])
        #expect(character.warnings(for: rigorMortis).isEmpty)
        #expect(character.freeRitualCount(for: "cruac") == 1)
    }

    @Test func thebanMiraclesNeedHumanity() {
        let character = character(disciplines: [("Theban Sorcery", 4)])
        character.humanity = 3
        let stigmata = Ritual(source: catalog.rituals.source(named: "Stigmata"))
        #expect(character.warnings(for: stigmata) == ["Casting requires Humanity 4"])

        character.humanity = 4
        #expect(character.warnings(for: stigmata).isEmpty)
    }

    @Test func cruacCapsHumanity() {
        let character = character(disciplines: [("Crúac", 3)])
        #expect(character.humanityCap == HumanityCap(limit: 7, disciplineName: "Crúac", dots: 3))
        #expect(Character().humanityCap == nil)
    }

    @Test func learningRitualsNeedsCovenantStatus() throws {
        let cruac = try #require(catalog.disciplines.entry("cruac"))
        let outsider = character(disciplines: [("Crúac", 1)])
        #expect(outsider.ritualLearningWarning(for: cruac) == "Learning rituals requires Circle of the Crone or Fir'awn Status 1")

        let acolyte = character(disciplines: [("Crúac", 1)], status: [("Circle of the Crone", 1)])
        #expect(acolyte.ritualLearningWarning(for: cruac) == nil)
        #expect(acolyte.showsRituals)
        #expect(!Character().showsRituals)
    }

    @Test func choosingAMysteryAddsItsCoil() {
        let character = Character()
        character.chooseMystery(.catalog("mystery-of-the-ascendant"))
        #expect(character.coils.map(\.mystery) == [.catalog("mystery-of-the-ascendant")])
        #expect(character.showsCoils)

        // Switching Mystery keeps the old Coil's dots
        character.coils[0].rating = 2
        character.chooseMystery(.catalog("mystery-of-the-wyrm"))
        #expect(character.coils.count == 2)
        #expect(character.coilRating("mystery-of-the-ascendant") == 2)
    }

    @Test func customMysteryKeepsItsCoilWhenRenamed() {
        let character = Character()
        character.renameMystery(to: "Mystery of the Serpent")
        character.coils[0].rating = 1
        character.renameMystery(to: "Mystery of the Serpents")

        #expect(character.coils.count == 1)
        #expect(character.coils[0].mystery == .custom("Mystery of the Serpents"))
        #expect(character.isMysteryCoil(character.coils[0]))
    }

    @Test func otherCoilsAreLimitedByOrdoDraculStatus() {
        let character = character(disciplines: [], status: [("Ordo Dracul", 1)])
        character.chooseMystery(.catalog("mystery-of-the-wyrm"))
        let own = character.coils[0]
        own.rating = 3
        let other = Coil(mystery: .catalog("mystery-of-the-voivode"), rating: 2)
        character.coils.append(other)

        #expect(character.warning(for: own) == nil)
        #expect(character.warning(for: other) == "Outside your Mystery, limited to Ordo\u{00A0}Dracul Status (1)")
        other.rating = 1
        #expect(character.warning(for: other) == nil)
    }

    @Test func scalesCostLessWithTheirPrerequisiteCoil() throws {
        let scale = try #require(catalog.scales.entry(named: "Kindred Sense Endowment"))
        let character = Character()
        #expect(character.experienceCost(of: scale) == 2)

        character.coils = [Coil(mystery: .catalog("mystery-of-the-wyrm"), rating: 2)]
        #expect(character.meetsPrerequisite(of: scale))
        #expect(character.experienceCost(of: scale) == 1)
        #expect(scale.prerequisiteText.hasSuffix("Hunger (Mystery of the Wyrm ••)"))
    }

    @Test func devotionPrerequisitesAreChecked() throws {
        let summoning = try #require(catalog.devotions.entry(named: "Summoning"))
        #expect(!character(disciplines: [("Majesty", 3)]).unmetPrerequisites(for: summoning).isEmpty)
        #expect(character(disciplines: [("Majesty", 4)]).unmetPrerequisites(for: summoning).isEmpty)

        let bodyOfWill = try #require(catalog.devotions.entry(named: "Body of Will"))
        let missingVigor = character(disciplines: [("Resilience", 3)]).unmetPrerequisites(for: bodyOfWill)
        #expect(missingVigor.map(\.description) == ["Vigor 1"])
    }

    @Test func devotionPoolsAddTheirNamedDiscipline() throws {
        let bodyOfWill = try #require(catalog.devotions.entry(named: "Body of Will"))
        let pool = try #require(bodyOfWill.dicePool)
        let character = character(disciplines: [("Resilience", 3), ("Vigor", 1)])
        // Stamina 1 raised to 4 by Resilience, Survival unskilled (−1), plus Resilience 3
        #expect(character.dice(for: pool) == 6)
        #expect(pool.formula(disciplineName: "") == "Stamina + Survival + Resilience")
    }
}
