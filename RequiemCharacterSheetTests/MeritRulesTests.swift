//
//  MeritRulesTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// Merit ratings, prerequisites and effect descriptions.
@MainActor
struct MeritRulesTests {

    private func merit(_ id: CatalogEntryID) throws -> MeritEntry {
        try #require(Catalog.bundled.merits.entry(id))
    }

    // MARK: - Ratings

    @Test func ratingsReadAsDots() throws {
        #expect(try merit("language").ratingsText == "●")
        #expect(try merit("fleet-of-foot").ratingsText == "● to ●●●")
        #expect(try merit("giant").ratingsText == "●●●")
        #expect(try merit("iron-skin").ratingsText == "●● or ●●●●")
        #expect(try merit("fleet-of-foot").ratingsText.spokenForVoiceOver == "1 dot to 3 dots")
    }

    @Test func ratingsSnapToAllowedValues() throws {
        let ironSkin = try merit("iron-skin") // 2 or 4

        #expect(ironSkin.allowedRating(for: 1) == 2)
        #expect(ironSkin.allowedRating(for: 3) == 4)
        #expect(ironSkin.allowedRating(for: 5) == 4)
        #expect(ironSkin.allowedRating(for: 0) == 0)
    }

    // MARK: - Prerequisites

    @Test func oneOfPrerequisitesNeedAnyOption() throws {
        let character = Character()
        let fastReflexes = try merit("fast-reflexes") // Wits 3 or Dexterity 3

        #expect(character.unmetPrerequisites(for: fastReflexes).map(\.description) == ["One of: Wits 3, or Dexterity 3"])

        character.attribute(.dexterity)?.rating = 3
        #expect(character.unmetPrerequisites(for: fastReflexes).isEmpty)
    }

    @Test func meritPrerequisitesNeedThatMerit() throws {
        let character = Character()
        let haven = try merit("haven")

        #expect(character.unmetPrerequisites(for: haven).map(\.description).contains("Safe Place"))

        character.merits = [Merit(name: "Safe Place", rating: 1)]
        #expect(character.unmetPrerequisites(for: haven).isEmpty)
    }

    @Test func covenantPrerequisitesNeedCovenantStatus() throws {
        let character = Character()
        let attache = try merit("attache")
        let invictusStatus = PrerequisiteCheck(description: "Invictus Status 1", isMet: false)

        #expect(character.prerequisiteChecks(for: attache).contains(invictusStatus))

        character.merits = [Merit(name: "Covenant Status (Invictus)", rating: 1)]
        #expect(character.prerequisiteChecks(for: attache).contains(PrerequisiteCheck(description: "Invictus Status 1", isMet: true)))
    }

    @Test func freeTextPrerequisitesAreShownButNotChecked() throws {
        let character = Character()
        let anonymity = try merit("anonymity")
        let checks = character.prerequisiteChecks(for: anonymity)

        #expect(checks.contains { $0.isMet == nil })
        #expect(!character.unmetPrerequisites(for: anonymity).contains { $0.isMet == nil })
    }

    // MARK: - Effects

    @Test func effectsAreDescribedForTheCharactersRating() throws {
        #expect(try merit("fast-reflexes").effects.map { $0.description(rating: 2, qualifier: nil) } == ["Adds 2 to Initiative"])
        #expect(try merit("small-framed").effects.map { $0.description(rating: 2, qualifier: nil) } == ["Subtracts 1 from Size (and so Health)"])
        #expect(try merit("defensive-combat").effects.map { $0.description(rating: 1, qualifier: "Brawl") }
            == ["Defense can use Brawl instead of Athletics"])
    }

    @Test func newCharactersStartWithoutMerits() {
        #expect(Character().merits.isEmpty)
    }
}
