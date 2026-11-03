//
//  CharacterTrackTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// Health, Willpower and Vitae stay in step with the ratings they depend on, immediately.
@MainActor
struct CharacterTrackTests {

    @Test func healthBoxesFollowStaminaAndSize() {
        let character = Character()
        #expect(character.healthBoxes.count == 6) // Stamina 1 + Size 5

        stamina(of: character)?.rating = 3
        #expect(character.healthBoxes.count == 8)

        character.size = 4
        #expect(character.healthBoxes.count == 7)
    }

    @Test func addingAndRemovingResilienceUpdatesHealthBoxes() {
        let character = Character()
        character.setHealthBox(at: 0, to: .lethal)

        character.disciplines.append(Discipline(name: "Resilience", rating: 2))
        #expect(character.healthBoxes.count == 8)
        #expect(character.healthBoxes.first == .lethal)

        character.disciplines.removeAll { $0.name == "Resilience" }
        #expect(character.healthBoxes.count == 6)
        #expect(character.healthBoxes.first == .lethal)
    }

    @Test func changingDisciplineRatingUpdatesHealthBoxes() {
        let character = Character()
        let resilience = Discipline(name: "Resilience", rating: 1)
        character.disciplines = [resilience]

        resilience.rating = 3

        #expect(character.healthBoxes.count == 9)
    }

    @Test func willpowerBoxesFollowResolveAndComposure() {
        let character = Character()
        character.setWillpowerBox(at: 1, to: .spent)
        #expect(character.willpowerBoxes == [.none, .spent])

        character.attributes.first { $0.name == "Resolve" }?.rating = 3
        #expect(character.willpowerBoxes == [.none, .spent, .none, .none])
    }

    @Test func skillChangesLeaveBoxesAlone() {
        let character = Character()
        character.setHealthBox(at: 2, to: .bashing)
        let boxesBefore = character.healthBoxes

        character.skills.first { $0.name == "Brawl" }?.rating = 4

        #expect(character.healthBoxes == boxesBefore)
    }

    @Test func markingBoxPastTrackEndExtendsTrack() {
        let character = Character()

        character.setHealthBox(at: 4, to: .aggravated)

        #expect(character.healthBoxes == [.none, .none, .none, .none, .aggravated, .none])
    }

    @Test func loweringBloodPotencyCapsCurrentVitaeImmediately() {
        let character = Character()
        character.bloodPotency = 6
        character.currentVitae = 20

        character.bloodPotency = 2

        #expect(character.maxVitae == 11)
        #expect(character.vitaePerTurn == 2)
        #expect(character.currentVitae == 11)
    }

    @Test func healthAndWillpowerMarksSurviveSaving() throws {
        let character = Character()
        character.setHealthBox(at: 0, to: .bashing)
        character.setHealthBox(at: 1, to: .lethal)
        character.setWillpowerBox(at: 0, to: .spent)

        let reloaded = try JSONDecoder().decode(Character.self, from: JSONEncoder().encode(character))

        #expect(reloaded.healthBoxes == character.healthBoxes)
        #expect(reloaded.willpowerBoxes == character.willpowerBoxes)
    }

    private func stamina(of character: Character) -> Attribute? {
        character.attributes.first { $0.name == "Stamina" }
    }
}
