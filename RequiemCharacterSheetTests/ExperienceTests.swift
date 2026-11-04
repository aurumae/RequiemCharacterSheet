//
//  ExperienceTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// XP Mode, the change log, Experience costs and refunds.
@MainActor
struct ExperienceTests {

    /// Makes a change to the character and records it, as the sheet does after each edit.
    private func change(_ character: Character, _ edit: () -> Void) {
        let before = character.traitSnapshot
        edit()
        character.recordChanges(since: before)
    }

    private func strength(_ character: Character) -> Attribute {
        character.attributes.first { $0.kind == .strength }!
    }

    // MARK: - XP Mode

    @Test func changesWithXPModeOffAreFreeButLogged() {
        let character = Character()
        change(character) { strength(character).rating = 3 }

        #expect(character.experiencesSpent == 0)
        let entry = character.changeLog.last
        #expect(entry?.name == "Strength")
        #expect(entry?.from == 1)
        #expect(entry?.to == 3)
        #expect(entry?.experiences == 0)
        #expect(entry?.xpMode == false)
    }

    @Test func raisingATraitInXPModeChargesPerDot() {
        let character = Character()
        character.experiences = 10
        character.xpMode = true
        change(character) { strength(character).rating = 3 }

        #expect(character.changeLog.last?.experiences == 8)
        #expect(character.experiencesSpent == 8)
        #expect(character.experiencesAvailable == 2)
    }

    @Test func availableExperiencesCanGoNegative() {
        let character = Character()
        character.experiences = 2
        character.xpMode = true
        change(character) { character.bloodPotency = 2 }

        #expect(character.experiencesAvailable == -3)
    }

    @Test func everyChangeIsDated() {
        let character = Character()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let before = character.traitSnapshot
        character.humanity = 6
        character.recordChanges(since: before, at: date)

        #expect(character.changeLog.last?.date == date)
    }

    @Test func unchangedTraitsAreNotLogged() {
        let character = Character()
        change(character) { character.name = "Marcus" }
        #expect(character.changeLog.isEmpty)
    }

    // MARK: - Refunds

    @Test func loweringRefundsOnlyPaidDots() {
        let character = Character()
        // Strength 2 entered for free, then a third dot bought
        change(character) { strength(character).rating = 2 }
        character.xpMode = true
        change(character) { strength(character).rating = 3 }
        #expect(character.experiencesSpent == 4)

        // Taking both dots back refunds only the bought one
        change(character) { strength(character).rating = 1 }
        #expect(character.changeLog.last?.experiences == -4)
        #expect(character.experiencesSpent == 0)
        #expect(character.paidDots[TraitKey(.attribute, "strength")] == nil)
    }

    @Test func loweringWithXPModeOffForgetsPaidDotsWithoutRefund() {
        let character = Character()
        character.xpMode = true
        change(character) { strength(character).rating = 2 }
        character.xpMode = false
        change(character) { strength(character).rating = 1 }

        #expect(character.experiencesSpent == 4)
        // Bought again later, it's charged again
        character.xpMode = true
        change(character) { strength(character).rating = 2 }
        #expect(character.experiencesSpent == 8)
    }

    @Test func losingHumanityOrBloodPotencyNeverRefunds() {
        let character = Character()
        character.xpMode = true
        change(character) { character.humanity = 8 }
        change(character) { character.bloodPotency = 2 }
        #expect(character.experiencesSpent == 2 + 5)

        change(character) { character.humanity = 5 }
        change(character) { character.bloodPotency = 1 }
        #expect(character.experiencesSpent == 7)
    }

    @Test func deletingAPaidTraitRefundsItAndKeepsItsName() {
        let character = Character()
        character.xpMode = true
        change(character) { character.merits.append(Merit(name: "Fleet of Foot", rating: 2)) }
        #expect(character.experiencesSpent == 2)

        change(character) { character.merits.removeAll() }
        #expect(character.changeLog.last?.name == "Fleet of Foot")
        #expect(character.changeLog.last?.to == 0)
        #expect(character.experiencesSpent == 0)
    }

    // MARK: - Costs

    @Test func disciplinesCostLessInClan() {
        let character = Character()
        character.clan = "Daeva"
        character.xpMode = true
        change(character) { character.disciplines.append(Discipline(name: "Celerity", rating: 1)) }
        change(character) { character.disciplines.append(Discipline(name: "Dominate", rating: 1)) }

        #expect(character.changeLog.map(\.experiences) == [3, 4])
    }

    @Test func bloodSorceryCostsFourPerDot() {
        let character = Character()
        character.xpMode = true
        change(character) { character.disciplines.append(Discipline(name: "Crúac", rating: 2)) }
        #expect(character.experiencesSpent == 8)
    }

    @Test func eachSorceryDotComesWithOneRitual() {
        let character = Character()
        character.disciplines = [Discipline(name: "Crúac", rating: 1)]
        character.xpMode = true
        change(character) { character.rituals.append(Ritual(source: .catalog("rigor-mortis"))) }
        change(character) { character.rituals.append(Ritual(source: .catalog("pangs-of-proserpina"))) }

        #expect(character.changeLog.map(\.experiences) == [0, 2])
    }

    @Test func skillsSpecialtiesAndMeritsHaveTheirOwnCosts() {
        let character = Character()
        character.xpMode = true
        let brawl = character.skills.first { $0.skillID == .brawl }!
        change(character) { brawl.rating = 2 }
        change(character) { brawl.specialties.append("Grappling") }
        change(character) { character.merits.append(Merit(name: "Resources", rating: 3)) }

        #expect(character.changeLog.map(\.experiences) == [4, 1, 3])
    }

    @Test func emptySpecialtiesAreFree() {
        let character = Character()
        character.xpMode = true
        let brawl = character.skills.first { $0.skillID == .brawl }!
        change(character) { brawl.specialties.append("") }
        #expect(character.changeLog.isEmpty)
    }

    @Test func coilsCostLessInTheCharactersMystery() {
        let character = Character()
        character.chooseMystery(.catalog("mystery-of-the-wyrm"))
        character.coils.append(Coil(mystery: .catalog("mystery-of-the-voivode")))
        character.xpMode = true
        change(character) { character.coils[0].rating = 1 }
        change(character) { character.coils[1].rating = 1 }

        #expect(character.changeLog.map(\.experiences) == [3, 4])
    }

    @Test func devotionsAndScalesCostWhatTheyList() {
        let character = Character()
        character.xpMode = true
        change(character) { character.devotions.append(Devotion(source: .catalog("body-of-will"))) }
        change(character) { character.devotions.append(Devotion(source: .custom("Homebrew"), customExperienceCost: 3)) }
        change(character) { character.scales.append(Scale(source: .catalog("kindred-sense-endowment"))) }

        // The Scale's prerequisite Coil isn't met, so it costs 2
        #expect(character.changeLog.map(\.experiences) == [2, 3, 2])
    }

    @Test func changingACustomDevotionsCostIsCharged() {
        let character = Character()
        let devotion = Devotion(source: .custom("Homebrew"), customExperienceCost: 1)
        character.xpMode = true
        change(character) { character.devotions.append(devotion) }
        change(character) { devotion.customExperienceCost = 3 }

        #expect(character.experiencesSpent == 3)
    }

    // MARK: - Saving

    @Test func logAndPaidDotsAreSaved() throws {
        let character = Character()
        character.xpMode = true
        change(character) { strength(character).rating = 2 }

        let data = try JSONEncoder().encode(character)
        let reloaded = try JSONDecoder().decode(Character.self, from: data)

        #expect(reloaded.xpMode)
        #expect(reloaded.changeLog == character.changeLog)
        #expect(reloaded.paidDots == [TraitKey(.attribute, "strength"): [2: 4]])

        // Saved as readable keys
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"attribute:strength\""))
    }

    @Test func version7SavesKeepTheirExperiencesToSpend() throws {
        let json = #"{"schemaVersion": 7, "experiences": 6}"#
        let character = try JSONDecoder().decode(Character.self, from: Data(json.utf8))

        #expect(!character.xpMode)
        #expect(character.changeLog.isEmpty)
        #expect(character.experiencesAvailable == 6)
    }

    // MARK: - Log wording

    @Test func logEntriesDescribeTheChangeAndItsCost() {
        let character = Character()
        character.disciplines = [Discipline(name: "Crúac", rating: 1)]
        change(character) { strength(character).rating = 2 }
        character.xpMode = true
        change(character) { strength(character).rating = 3 }
        change(character) { strength(character).rating = 2 }
        change(character) { character.rituals.append(Ritual(source: .catalog("rigor-mortis"))) }

        #expect(character.changeLog.map(\.changeText) == ["1 → 2", "2 → 3", "3 → 2", "Learned"])
        #expect(character.changeLog.map(\.costText) == ["Free", "Spent 4", "Refunded 4", "No cost"])
    }

    @Test func logNamesCustomTraitsNamedAfterTheyWereAdded() {
        let character = Character()
        let discipline = Discipline(source: .custom(""), rating: 1)
        change(character) { character.disciplines.append(discipline) }
        #expect(character.displayName(for: character.changeLog[0]) == "Unnamed Discipline")

        discipline.name = "Blood Magic"
        #expect(character.displayName(for: character.changeLog[0]) == "Blood Magic")
    }
}
