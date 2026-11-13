//
//  ConditionTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet
#if SWIFT_PACKAGE
@testable import ChroniclesCore
#endif

/// The Condition catalog, adding, ending and resolving Conditions, their Beats, log and saving.
@MainActor
struct ConditionTests {

    private func condition(_ id: String, note: String = "") -> CharacterCondition {
        CharacterCondition(source: .catalog(id), note: note)
    }

    // MARK: - Catalog

    @Test func requiemConditionsAreInTheCatalog() throws {
        let conditions = Catalog.bundled.conditions.all
        let requiem = conditions.filter { $0.source.book == "vtr2e-core" }
        #expect(requiem.count == 44)
        #expect(requiem.allSatisfy { (301...307).contains($0.source.page ?? 0) })
        #expect(Set(conditions.map(\.id)).count == conditions.count)
        let charmed = try #require(Catalog.bundled.conditions.entry("charmed"))
        #expect(charmed.persistent)
        #expect(charmed.beat != nil)
        #expect(charmed.notePrompt == "By")
        let bestial = try #require(Catalog.bundled.conditions.entry("bestial"))
        #expect(!bestial.persistent)
        #expect(bestial.beat == nil)
    }

    @Test func chroniclesOfDarknessAddsOnlyItsOwnConditions() throws {
        // Ones the Requiem book also has, like Broken, are listed once, as Requiem's
        let core = Catalog.bundled.conditions.all.filter { $0.source.book == "cofd-core" }
        #expect(core.map(\.id).sorted() == ["blind", "bonded", "connected", "crippled", "embarrassing-secret",
                                             "informed", "leveraged", "lost", "madness", "mute", "notoriety"])
        #expect(core.allSatisfy { (288...290).contains($0.source.page ?? 0) })
        #expect(Catalog.bundled.conditions.entry("broken")?.source.book == "vtr2e-core")
    }

    @Test func catalogFlagsFollowTheCards() throws {
        let entries = Catalog.bundled.conditions
        #expect(entries.all.filter { !$0.beatOnResolve }.map(\.id).sorted() == ["distracted", "stumbled"])
        #expect(entries.all.filter(\.repeatable).map(\.id).sorted() == ["addicted", "anchored-heart", "beloved-enemy", "leveraged", "shamed", "suspicious", "swooning", "tainted"])
        #expect(entries.all.filter(\.counter).map(\.id).sorted() == ["languid", "lethargic", "tempted"])
    }

    @Test func everyEffectTargetIsKnown() throws {
        // Targets this version can't read are dropped, so a typo would silently lose an indicator
        let file = try JSONSerialization.jsonObject(with: catalogData()) as? [String: Any]
        let conditions = try #require(file?["conditions"] as? [[String: Any]])
        for condition in conditions {
            for effect in condition["affects"] as? [[String: Any]] ?? [] {
                for target in effect["targets"] as? [String] ?? [] {
                    #expect(ConditionTarget(target) != nil, "\(condition["id"] ?? "") has unknown target \(target)")
                }
            }
        }
        #expect(Catalog.bundled.conditions.entry("deprived")?.affects.first?.targets
                == [.attribute(.stamina), .attribute(.resolve), .attribute(.composure)])
    }

    private func catalogData() throws -> Data {
        #if SWIFT_PACKAGE
        let url = try #require(Bundle.module.url(forResource: "vtr2e-core", withExtension: "json"))
        #else
        let url = try #require(Bundle.main.url(forResource: "vtr2e-core", withExtension: "json"))
        #endif
        return try Data(contentsOf: url)
    }

    // MARK: - Adding and removing

    @Test func addingLogsTheCondition() {
        let character = Character()
        character.addCondition(condition("swooning", note: "Marcus Vale"))

        #expect(character.conditions.map(\.name) == ["Swooning"])
        let entry = character.changeLog.last
        #expect(entry?.event == .added)
        #expect(entry?.name == "Swooning (Marcus Vale)")
        #expect(entry?.changeText == "Added")
        #expect(entry?.experiences == 0)
    }

    @Test func logNamesFollowTheNoteTypedAfterAdding() throws {
        let character = Character()
        let swooning = condition("swooning")
        character.addCondition(swooning)
        swooning.note = "Marcus Vale"
        let added = try #require(character.changeLog.last)

        #expect(character.displayName(for: added) == "Swooning (Marcus Vale)")
        character.resolveCondition(swooning)
        // Once it's gone, as it was when it ended
        #expect(character.displayName(for: added) == "Swooning (Marcus Vale)")
    }

    @Test func resolvingGivesABeat() {
        let character = Character()
        let charmed = condition("charmed")
        character.addCondition(charmed)

        character.resolveCondition(charmed)

        #expect(character.conditions.isEmpty)
        #expect(character.beats == 1)
        #expect(character.changeLog.last?.event == .resolved)
        #expect(character.changeLog.last?.costText == "+1 Beat")
    }

    @Test func someConditionsGiveNoBeatWhenResolved() {
        let character = Character()
        let distracted = condition("distracted")
        character.addCondition(distracted)

        character.resolveCondition(distracted)

        #expect(character.beats == 0)
        #expect(character.changeLog.last?.beats == nil)
    }

    @Test func endingGivesNoBeat() {
        let character = Character()
        let charmed = condition("charmed")
        character.addCondition(charmed)

        character.endCondition(charmed)

        #expect(character.conditions.isEmpty)
        #expect(character.beats == 0)
        #expect(character.changeLog.last?.event == .ended)
    }

    @Test func aBeatKeepsTheCondition() {
        let character = Character()
        let charmed = condition("charmed")
        character.addCondition(charmed)

        character.takeBeat(from: charmed)
        character.takeBeat(from: charmed)

        #expect(character.conditions.count == 1)
        #expect(character.beats == 2)
        #expect(character.changeLog.filter { $0.event == .beat }.count == 2)
    }

    @Test func fiveBeatsMakeAnExperience() {
        let character = Character()
        let charmed = condition("charmed")
        character.addCondition(charmed)
        character.beats = 4

        character.takeBeat(from: charmed)

        #expect(character.beats == 0)
        #expect(character.experiences == 1)
    }

    @Test func conditionsCostNoExperiences() {
        let character = Character()
        character.experiences = 3
        character.xpMode = true
        let charmed = condition("charmed")

        character.addCondition(charmed)
        character.resolveCondition(charmed)

        #expect(character.experiencesSpent == 0)
    }

    @Test func onlySomeConditionsCanBeTakenTwice() throws {
        let character = Character()
        character.addCondition(condition("swooning", note: "Marcus"))
        character.addCondition(condition("charmed"))

        #expect(character.canAdd(try #require(Catalog.bundled.conditions.entry("swooning"))))
        #expect(!character.canAdd(try #require(Catalog.bundled.conditions.entry("charmed"))))
        #expect(character.canAdd(try #require(Catalog.bundled.conditions.entry("bestial"))))
    }

    @Test func countersStartAtOne() {
        let character = Character()
        let tempted = condition("tempted")
        character.addCondition(tempted)

        #expect(tempted.counter == 1)
        #expect(tempted.titleWithCounter == "Tempted −1")
        tempted.counter = 3
        #expect(tempted.titleWithCounter == "Tempted −3")
        let charmed = condition("charmed")
        character.addCondition(charmed)
        #expect(charmed.counter == 0)
        #expect(charmed.titleWithCounter == "Charmed")
    }

    @Test func recentConditionsAreNewestFirstAndOnce() {
        let character = Character()
        for id in ["charmed", "swooning", "charmed", "tempted"] {
            let added = condition(id)
            character.addCondition(added)
            character.endCondition(added)
        }
        let custom = CharacterCondition(source: .custom("Homebrew"))
        character.addCondition(custom)

        #expect(character.recentConditionIDs() == ["tempted", "charmed", "swooning"])
    }

    @Test func effectsAreFoundByTarget() {
        let character = Character()
        character.addCondition(condition("deprived"))
        character.addCondition(condition("confused"))

        #expect(character.conditionEffects(on: .attribute(.stamina)).map(\.text)
                == ["Deprived: −1 to dice pools using Stamina, Resolve or Composure"])
        #expect(character.conditionEffects(on: .attribute(.wits)).map(\.condition.name) == ["Confused"])
        #expect(character.conditionEffects(on: .attribute(.strength)).isEmpty)
    }

    // MARK: - Custom Conditions

    @Test func customConditionsUseTheirOwnText() {
        let custom = CharacterCondition(source: .custom("Cursed"))
        custom.customEffect = "Everything goes wrong."
        custom.customBeat = "Something goes wrong."
        custom.customPersistent = true

        #expect(custom.name == "Cursed")
        #expect(custom.effectText == "Everything goes wrong.")
        #expect(custom.beatText == "Something goes wrong.")
        #expect(custom.isPersistent)
        #expect(custom.givesBeatOnResolve)
        custom.customBeat = "  "
        #expect(custom.beatText == nil)
    }

    // MARK: - Saving

    @Test func conditionsSurviveSaving() throws {
        let character = Character()
        let tempted = condition("tempted")
        character.addCondition(tempted)
        tempted.counter = 2
        let custom = CharacterCondition(source: .custom("Cursed"), note: "By the witch")
        custom.customEffect = "Everything goes wrong."
        character.addCondition(custom)
        character.takeBeat(from: custom)

        let loaded = try JSONDecoder().decode(Character.self, from: JSONEncoder().encode(character))

        #expect(loaded.conditions.map(\.name) == ["Tempted", "Cursed"])
        #expect(loaded.conditions.first?.counter == 2)
        #expect(loaded.conditions.last?.note == "By the witch")
        #expect(loaded.conditions.last?.customEffect == "Everything goes wrong.")
        #expect(loaded.changeLog.map(\.event) == [.added, .added, .beat])
        #expect(loaded.beats == 1)
    }

    @Test func aLoggedConditionKeepsVersion11AfterItEnds() throws {
        let character = Character()
        let charmed = condition("charmed")
        character.addCondition(charmed)
        character.endCondition(charmed)

        // Its log entries still need an app that can read them
        #expect(character.savedSchemaVersion == 11)
        #expect(Character().savedSchemaVersion == 10)
    }

    @Test func catalogConditionsSaveOnlyTheirSource() throws {
        let character = Character()
        character.addCondition(condition("charmed", note: "Lady Ysolde"))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(character)) as? [String: Any]
        let saved = try #require((json?["conditions"] as? [[String: Any]])?.first)

        #expect(saved["source"] as? [String: String] == ["catalog": "charmed"])
        #expect(saved["note"] as? String == "Lady Ysolde")
        #expect(saved["customEffect"] == nil)
    }
}
