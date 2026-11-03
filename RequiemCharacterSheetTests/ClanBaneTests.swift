//
//  ClanBaneTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// Clan banes take hold when Humanity first falls to 6 and stay, unless the player switches them off.
@MainActor
struct ClanBaneTests {

    private func makeDaeva() -> Character {
        let character = Character()
        character.clan = "Daeva"
        return character
    }

    @Test func newCharactersStartWithoutTheirClanBane() {
        let character = makeDaeva()

        #expect(character.humanity == 7)
        #expect(!character.clanBaneActive)
        #expect(character.clanBaneThreshold == 6)
    }

    @Test func fallingToHumanitySixActivatesTheClanBane() {
        let character = makeDaeva()

        character.humanity = 6

        #expect(character.clanBaneActive)
    }

    @Test func clanBaneStaysWhenHumanityRises() {
        let character = makeDaeva()
        character.humanity = 5

        character.humanity = 8

        #expect(character.clanBaneActive)
    }

    @Test func switchedOffClanBaneStaysOffUntilHumanityFallsToSixAgain() {
        let character = makeDaeva()
        character.humanity = 6
        // e.g. the player was only trying out changes
        character.clanBaneActive = false

        character.humanity = 4
        #expect(!character.clanBaneActive)

        character.humanity = 7
        character.humanity = 6
        #expect(character.clanBaneActive)
    }

    @Test func choosingAClanAtLowHumanityPutsItsBaneInEffect() {
        let character = Character()
        character.humanity = 5
        #expect(!character.clanBaneActive) // no clan yet

        character.clan = "Gangrel"

        #expect(character.clanBaneActive)
    }

    @Test func typingACustomClanDoesntActivateABane() {
        let character = Character()
        character.humanity = 5

        character.clan = "Homebrew Bloodline"

        #expect(!character.clanBaneActive)
    }

    @Test func everyClanUsesHumanitySix() {
        for clan in ["Ventrue", "Akhud", "Mekhet"] {
            let character = Character()
            character.clan = clan
            character.humanity = 6
            #expect(character.clanBaneActive, "\(clan)")
        }
    }

    @Test func olderSavesInferTheClanBaneFromHumanity() throws {
        let fallen = try JSONDecoder().decode(Character.self, from: Data(#"{"clan": "Gangrel", "humanity": 5}"#.utf8))
        let intact = try JSONDecoder().decode(Character.self, from: Data(#"{"clan": "Gangrel", "humanity": 7}"#.utf8))

        #expect(fallen.clanBaneActive)
        #expect(!intact.clanBaneActive)
    }

    @Test func clanBaneStateIsSaved() throws {
        let character = makeDaeva()
        character.humanity = 5
        character.clanBaneActive = false

        let reloaded = try JSONDecoder().decode(Character.self, from: JSONEncoder().encode(character))

        #expect(reloaded.humanity == 5)
        #expect(!reloaded.clanBaneActive)
    }

    @Test func mekhetBaneGrantsAnExtraBane() {
        #expect(Catalog.bundled.clans.entry("mekhet")?.bane.grantsExtraBane == true)
        #expect(Catalog.bundled.clans.entry("daeva")?.bane.grantsExtraBane == false)
    }

    @Test func banesAreCappedAtThree() {
        let character = Character()
        character.banes = [Bane(text: "Bells"), Bane(text: "Webs")]
        #expect(character.canAddBane)

        character.banes.append(Bane(text: "Symbols"))
        #expect(!character.canAddBane)
    }
}
