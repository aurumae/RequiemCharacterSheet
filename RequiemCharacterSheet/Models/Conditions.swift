//
//  Conditions.swift
//  RequiemCharacterSheet
//

import Foundation
import Observation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

/// A Condition looked up in the bundled catalogs.
extension CharacterCondition {
    /// The catalog entry, if this isn't a custom Condition.
    var entry: ConditionEntry? {
        source.catalogID.flatMap { Catalog.bundled.conditions.entry($0) }
    }

    var name: String {
        get { Catalog.bundled.conditions.name(of: source) }
        set { source = Catalog.bundled.conditions.source(named: newValue) }
    }

    var isPersistent: Bool { entry?.persistent ?? customPersistent }
    var effectText: String { entry?.summary ?? customEffect }
    var resolutionText: String { entry?.resolution ?? customResolution }
    /// How it earns a Beat while it lasts, or `nil` if it doesn't.
    var beatText: String? {
        if let entry { return entry.beat }
        let beat = customBeat.trimmingCharacters(in: .whitespacesAndNewlines)
        return beat.isEmpty ? nil : beat
    }
    var givesBeatOnResolve: Bool { entry?.beatOnResolve ?? true }
    var hasCounter: Bool { entry?.counter ?? false }

    /// e.g. "Tempted −3", or "Swooning".
    var titleWithCounter: String {
        hasCounter && counter > 0 ? "\(name) −\(counter)" : name
    }

}

extension Character {
    /// The log's key for a Condition: "condition:<catalog id or custom>/<UUID>", so recently used
    /// Conditions can be found again from the log.
    private func logKey(for condition: CharacterCondition) -> TraitKey {
        TraitKey(.condition, "\(condition.source.catalogID ?? "custom")/\(condition.id.uuidString)")
    }

    /// e.g. "Swooning (Marcus Vale)" or "Tempted −2".
    func logName(for condition: CharacterCondition) -> String {
        let title = condition.name.isEmpty ? "" : condition.titleWithCounter
        return condition.note.isEmpty ? title : "\(title) (\(condition.note))"
    }

    /// The Condition a log entry is about, if it's still on the character.
    func condition(for change: TraitChange) -> CharacterCondition? {
        guard change.trait.kind == .condition, let slash = change.trait.id.firstIndex(of: "/") else { return nil }
        let id = UUID(uuidString: String(change.trait.id[change.trait.id.index(after: slash)...]))
        return conditions.first { $0.id == id }
    }

    private func logCondition(_ condition: CharacterCondition, _ event: ConditionEvent, beats: Int = 0, at date: Date) {
        let name = logName(for: condition)
        changeLog.append(TraitChange(
            id: UUID(), date: date, trait: logKey(for: condition), name: name,
            from: event == .added ? 0 : 1, to: event == .added || event == .beat ? 1 : 0,
            experiences: 0, xpMode: xpMode, duringCreation: isInCreation ? true : nil,
            event: event, beats: beats > 0 ? beats : nil
        ))
    }

    /// Whether the character can take this Condition now: not if they have it and it can't be doubled up.
    func canAdd(_ entry: ConditionEntry) -> Bool {
        entry.repeatable || !conditions.contains { $0.source == .catalog(entry.id) }
    }

    func addCondition(_ condition: CharacterCondition, at date: Date = .now) {
        if condition.hasCounter && condition.counter == 0 {
            condition.counter = 1
        }
        conditions.append(condition)
        logCondition(condition, .added, at: date)
    }

    /// Removes the Condition without a Beat, e.g. when it fades or the Storyteller ends it.
    func endCondition(_ condition: CharacterCondition, at date: Date = .now) {
        conditions.removeAll { $0.id == condition.id }
        logCondition(condition, .ended, at: date)
    }

    /// Removes the Condition, with a Beat unless it says resolving it gives none.
    func resolveCondition(_ condition: CharacterCondition, at date: Date = .now) {
        conditions.removeAll { $0.id == condition.id }
        let beats = condition.givesBeatOnResolve ? 1 : 0
        if beats > 0 { incrementBeats() }
        logCondition(condition, .resolved, beats: beats, at: date)
    }

    /// A Beat for meeting the Condition's Beat while it lasts. The Condition stays.
    func takeBeat(from condition: CharacterCondition, at date: Date = .now) {
        incrementBeats()
        logCondition(condition, .beat, beats: 1, at: date)
    }

    /// Catalog Conditions added most recently first, each once.
    func recentConditionIDs(limit: Int = 5) -> [CatalogEntryID] {
        var seen = Set<CatalogEntryID>()
        var ids: [CatalogEntryID] = []
        for change in changeLog.reversed() where change.trait.kind == .condition && change.event == .added {
            let id = String(change.trait.id.prefix { $0 != "/" })
            guard id != "custom", Catalog.bundled.conditions.entry(id) != nil, seen.insert(id).inserted else { continue }
            ids.append(id)
            if ids.count == limit { break }
        }
        return ids
    }

    /// What active Conditions do to a trait, e.g. "Deprived: −1 to dice pools using Stamina…", one line each.
    func conditionEffects(on target: ConditionTarget) -> [(condition: CharacterCondition, text: String)] {
        conditions.flatMap { condition in
            (condition.entry?.affects ?? []).filter { $0.targets.contains(target) }.map { (condition, $0.text) }
        }
    }
}
