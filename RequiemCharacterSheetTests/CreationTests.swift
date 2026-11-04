//
//  CreationTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// Guided creation's starting dots, inferred priorities and hard limits.
@MainActor
struct CreationTests {

    private func newCharacter(clan: String = "Daeva") -> Character {
        let character = Character()
        character.clan = clan
        character.creation = CreationState()
        return character
    }

    private func set(_ kind: AttributeKind, _ rating: Int, on character: Character) {
        character.attributes.first { $0.kind == kind }?.rating = rating
    }

    private func set(_ skill: SkillID, _ rating: Int, on character: Character) {
        character.skills.first { $0.skillID == skill }?.rating = rating
    }

    private func statusMerit(_ covenant: String, _ rating: Int = 1) -> Merit {
        Merit(source: .catalog("covenant-status"), qualifier: covenant, rating: rating)
    }

    // MARK: - Attributes

    @Test func attributePrioritiesFollowTheDots() {
        let character = newCharacter(clan: "")
        set(.strength, 4, on: character)   // Physical: 3 + 2 = 5
        set(.dexterity, 3, on: character)
        set(.wits, 3, on: character)       // Mental: 2 + 2 = 4
        set(.resolve, 3, on: character)
        set(.presence, 4, on: character)   // Social: 3

        let report = character.creationReport
        #expect(report.attributes[.physical] == CreationBudget(used: 5, allowed: 5))
        #expect(report.attributes[.mental] == CreationBudget(used: 4, allowed: 4))
        #expect(report.attributes[.social] == CreationBudget(used: 3, allowed: 3))
        #expect(report.isWithinLimits)
    }

    @Test func theClansFavoredAttributeGetsAFreeDot() {
        // Daeva favour Dexterity or Manipulation
        let character = newCharacter()
        set(.strength, 4, on: character)
        set(.dexterity, 4, on: character)  // Physical: 3 + 3 = 6, less the clan's dot = 5
        set(.wits, 3, on: character)
        set(.resolve, 3, on: character)
        set(.presence, 4, on: character)

        let report = character.creationReport
        #expect(report.favoredAttribute == .dexterity)
        #expect(report.attributes[.physical] == CreationBudget(used: 5, allowed: 5))
        #expect(report.isWithinLimits)
    }

    @Test func attributesCantGoBeyondTheirBudget() {
        let character = newCharacter(clan: "")
        set(.strength, 4, on: character)
        set(.dexterity, 4, on: character)  // Physical 6: over every allotment
        #expect(character.creationReport.problems.contains(.attributesOverBudget))
    }

    @Test func attributeLimitsAreHard() {
        let character = newCharacter(clan: "")
        set(.strength, 5, on: character)
        set(.dexterity, 2, on: character)  // Physical 5, the primary allotment, used up
        let stamina = TraitKey(.attribute, AttributeKind.stamina.rawValue)

        // Mental can still take 4, so Stamina can't rise at all while Physical is primary
        #expect(character.creationMaximum(for: stamina, upTo: 5) == 1)
        // Mental's Wits can take up to the secondary 4 extra dots, but no more than 5
        #expect(character.creationMaximum(for: TraitKey(.attribute, AttributeKind.wits.rawValue), upTo: 5) == 5)
    }

    @Test func limitsDontApplyOutsideCreation() {
        let character = Character()
        #expect(character.creationMaximum(for: TraitKey(.attribute, "strength"), upTo: 5) == nil)
        #expect(character.editableMaximum(for: TraitKey(.attribute, "strength"), upTo: 5) == 5)
        #expect(character.creationAllows(.discipline(nil)))
    }

    // MARK: - Skills and Specialties

    @Test func skillPrioritiesFollowTheDots() {
        let character = newCharacter()
        set(.brawl, 3, on: character)
        set(.athletics, 3, on: character)
        set(.stealth, 3, on: character)
        set(.weaponry, 2, on: character)   // Physical 11
        set(.academics, 4, on: character)
        set(.occult, 3, on: character)     // Mental 7
        set(.persuasion, 4, on: character) // Social 4

        let report = character.creationReport
        #expect(report.skills[.physical] == CreationBudget(used: 11, allowed: 11))
        #expect(report.skills[.mental] == CreationBudget(used: 7, allowed: 7))
        #expect(report.skills[.social] == CreationBudget(used: 4, allowed: 4))
        #expect(report.isWithinLimits)

        set(.socialize, 1, on: character)
        #expect(character.creationReport.problems.contains(.skillsOverBudget))
    }

    @Test func threeSpecialties() {
        let character = newCharacter()
        let brawl = character.skills.first { $0.skillID == .brawl }!
        brawl.specialties = ["Grappling", "Biting"]
        #expect(character.canAddSpecialty)
        brawl.specialties.append("Dirty Tricks")
        #expect(!character.canAddSpecialty)
        #expect(Character().canAddSpecialty)
    }

    // MARK: - Disciplines

    @Test func threeDisciplineDotsAtLeastTwoInClan() {
        let character = newCharacter()
        character.disciplines = [Discipline(name: "Celerity", rating: 2)]
        #expect(character.creationAllows(.discipline(Catalog.bundled.disciplines.entry("dominate"))))

        character.disciplines.append(Discipline(name: "Dominate", rating: 1))
        #expect(character.creationReport.disciplines == CreationBudget(used: 3, allowed: 3))
        #expect(character.creationReport.isWithinLimits)
        #expect(!character.creationAllows(.discipline(Catalog.bundled.disciplines.entry("vigor"))))
    }

    @Test func twoOutOfClanDotsAreRefused() {
        let character = newCharacter()
        character.disciplines = [Discipline(name: "Celerity", rating: 1), Discipline(name: "Dominate", rating: 2)]
        #expect(character.creationReport.problems.contains(.tooFewInClanDisciplineDots))

        let dominate = TraitKey(.discipline, character.disciplines[1].id.uuidString)
        #expect(character.creationMaximum(for: dominate, upTo: 5) == 2)
    }

    @Test func bloodSorceryNeedsCovenantStatus() {
        let character = newCharacter()
        character.disciplines = [Discipline(name: "Celerity", rating: 2)]
        let cruac = Catalog.bundled.disciplines.entry("cruac")
        #expect(!character.creationAllows(.discipline(cruac)))

        character.merits = [statusMerit("Circle of the Crone")]
        #expect(character.creationAllows(.discipline(cruac)))
    }

    @Test func theMysteryCoilCanBeTheThirdDot() {
        let character = newCharacter()
        character.disciplines = [Discipline(name: "Celerity", rating: 2)]
        character.chooseMystery(.catalog("mystery-of-the-wyrm"))
        let coil = TraitKey(.coil, character.coils[0].id.uuidString)
        #expect(character.creationMaximum(for: coil, upTo: 5) == 0)

        character.merits = [statusMerit("Ordo Dracul")]
        #expect(character.creationMaximum(for: coil, upTo: 5) == 1)

        // Other Mysteries' Coils can't be learned at creation
        character.coils.append(Coil(mystery: .catalog("mystery-of-the-voivode")))
        #expect(character.creationMaximum(for: TraitKey(.coil, character.coils[1].id.uuidString), upTo: 5) == 0)
    }

    @Test func oneRitualPerSorceryDot() {
        let character = newCharacter()
        character.merits = [statusMerit("Circle of the Crone")]
        character.disciplines = [Discipline(name: "Celerity", rating: 2), Discipline(name: "Crúac", rating: 1)]
        let cruac = TraitSource.catalog("cruac")
        #expect(character.creationAllows(.ritual(discipline: cruac, dots: 1)))
        #expect(!character.creationAllows(.ritual(discipline: cruac, dots: 2)))

        character.rituals = [Ritual(source: .catalog("rigor-mortis"))]
        #expect(!character.creationAllows(.ritual(discipline: cruac, dots: 1)))
    }

    @Test func devotionsAndScalesWaitUntilAfterCreation() {
        let character = newCharacter()
        #expect(!character.canLearnDevotionsAndScales)
        character.devotions = [Devotion(source: .catalog("body-of-will"))]
        #expect(character.creationReport.problems.contains(.devotionsOrScales))
        #expect(Character().canLearnDevotionsAndScales)
    }

    // MARK: - Merits, Blood Potency and Humanity

    @Test func tenMeritDotsWithBloodPotencyAtFiveEach() {
        let character = newCharacter()
        character.merits = [Merit(name: "Resources", rating: 3)]
        character.bloodPotency = 2
        #expect(character.creationReport.merits == CreationBudget(used: 8, allowed: 10))

        let resources = TraitKey(.merit, character.merits[0].id.uuidString)
        #expect(character.creationMaximum(for: resources, upTo: 5) == 5)
        #expect(character.creationMaximum(for: TraitKey(.bloodPotency, "bloodPotency"), upTo: 10) == 2)

        character.merits[0].rating = 0
        #expect(character.creationMaximum(for: TraitKey(.bloodPotency, "bloodPotency"), upTo: 10) == 3)
    }

    @Test func meritsKindredCantTakeAreRefused() throws {
        let character = newCharacter()
        let telepathy = try #require(Catalog.bundled.merits.entry("telepathy"))
        #expect(telepathy.category == .supernatural)
        #expect(!character.creationAllows(.merit(telepathy, rating: 3)))
        #expect(!character.creationAllows(.merit(Catalog.bundled.merits.entry("virtuous"), rating: 2)))
        #expect(character.creationAllows(.merit(Catalog.bundled.merits.entry("resources"), rating: 3)))

        // Outside creation it's a warning on the Merit instead
        #expect(Character().unmetPrerequisites(for: telepathy).first?.description == "Not available to Kindred")
    }

    @Test func meritPrerequisitesAreHardLimitsAtCreation() throws {
        let attache = try #require(Catalog.bundled.merits.entry("attache"))
        let character = newCharacter()
        #expect(!character.creationAllows(.merit(attache, rating: 1)))
        #expect(Character().creationAllows(.merit(attache, rating: 1)))

        character.merits = [statusMerit("Invictus")]
        #expect(character.creationAllows(.merit(attache, rating: 1)) == character.unmetPrerequisites(for: attache).isEmpty)
    }

    @Test func humanityStartsAtSeven() {
        let character = newCharacter()
        #expect(character.creationMaximum(for: TraitKey(.humanity, "humanity"), upTo: 10) == 7)
    }

    // MARK: - Saving and data

    @Test func creationStateIsSaved() throws {
        let character = newCharacter()
        character.creation?.bonusExperiences = 15
        let reloaded = try JSONDecoder().decode(Character.self, from: JSONEncoder().encode(character))
        #expect(reloaded.creation == CreationState(bonusExperiences: 15))

        let finished = try JSONDecoder().decode(Character.self, from: JSONEncoder().encode(Character()))
        #expect(finished.creation == nil)
    }

    @Test func maskAndDirgeArchetypes() {
        let archetypes = Catalog.bundled.archetypes.all
        #expect(archetypes.count == 27)
        #expect(archetypes.first?.name == "Authoritarian")
        #expect(Catalog.bundled.archetypes.entry(named: "social chameleon") != nil)
    }

    // MARK: - Steps, finishing and leaving

    @Test func guidedCharactersStartInCreation() {
        let character = Character.guided()
        #expect(character.isInCreation)
        #expect(!character.xpMode)
        #expect(!Character().isInCreation)
    }

    @Test func stepsShowTheBudgets() {
        let character = newCharacter()
        set(.strength, 3, on: character)
        let steps = character.creationSteps

        #expect(steps.map(\.number) == Array(1...7))
        #expect(steps[1].detail == "Mental 2 of 5 · Physical 0 of 4 · Social 0 of 3"
                || steps[1].detail.hasPrefix("Physical 2 of 5"))
        #expect(steps[1].status == .inProgress)
        #expect(steps[4].detail.hasPrefix("Needs Mask, Dirge, Touchstone"))
        #expect(steps[6].status == .done)
    }

    @Test func aStepIsDoneWhenItsDotsAreSpent() {
        let character = newCharacter(clan: "")
        let brawl = character.skills.first { $0.skillID == .brawl }!
        brawl.specialties = ["Grappling", "Biting", "Dirty Tricks"]
        #expect(character.creationSteps[3].status == .done)
    }

    @Test func aBrokenRuleMarksItsStep() {
        let character = newCharacter()
        character.disciplines = [Discipline(name: "Dominate", rating: 2)]
        #expect(character.creationSteps[4].status == .problem)
        #expect(character.unfinishedCreationSteps.contains { $0.number == 5 })
    }

    @Test func finishingAddsBonusExperiencesAndTurnsOnXPMode() {
        let character = newCharacter()
        character.experiences = 2
        character.finishCreation(bonusExperiences: 15)

        #expect(!character.isInCreation)
        #expect(character.experiences == 17)
        #expect(character.xpMode)
        #expect(CreationRules.experiencedRanks.map(\.experiences) == [0, 5, 10, 15, 25, 35, 50, 100])
    }

    @Test func leavingKeepsEverythingWithoutLimits() {
        let character = newCharacter()
        set(.strength, 3, on: character)
        character.leaveCreation()

        #expect(!character.isInCreation)
        #expect(!character.xpMode)
        #expect(character.attributes.first { $0.kind == .strength }?.rating == 3)
        #expect(character.creationMaximum(for: TraitKey(.attribute, "strength"), upTo: 5) == nil)
    }

    @Test func changesDuringCreationAreLoggedAsCreation() {
        let character = newCharacter()
        let before = character.traitSnapshot
        set(.strength, 2, on: character)
        character.recordChanges(since: before)

        #expect(character.changeLog.last?.duringCreation == true)
        #expect(character.changeLog.last?.costText == "Creation")
    }
}
