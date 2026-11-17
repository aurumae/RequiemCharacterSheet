//
//  ConditionRules.swift
//  ChroniclesCore
//
//  Adding, ending and resolving Conditions, and the Beats and log entries they bring, for any game with a Condition
//  catalog.
//

import Foundation

/// A character whose game has Conditions.
package protocol ConditionsCharacter: ChroniclesCharacter {
    /// The game's Conditions.
    var conditionCatalog: CatalogIndex<ConditionEntry> { get }
    /// Whether the character is being made with guided creation, which their log notes.
    var isInCreation: Bool { get }
}

extension CharacterCondition {
    /// The catalog entry, if this isn't a custom Condition.
    package func entry(in catalog: CatalogIndex<ConditionEntry>) -> ConditionEntry? {
        source.catalogID.flatMap { catalog.entry($0) }
    }

    package func name(in catalog: CatalogIndex<ConditionEntry>) -> String {
        catalog.name(of: source)
    }

    package func hasCounter(in catalog: CatalogIndex<ConditionEntry>) -> Bool {
        entry(in: catalog)?.counter ?? false
    }

    package func givesBeatOnResolve(in catalog: CatalogIndex<ConditionEntry>) -> Bool {
        entry(in: catalog)?.beatOnResolve ?? true
    }

    /// e.g. "Tempted −3", or "Swooning".
    package func titleWithCounter(in catalog: CatalogIndex<ConditionEntry>) -> String {
        hasCounter(in: catalog) && counter > 0 ? "\(name(in: catalog)) −\(counter)" : name(in: catalog)
    }
}

extension ConditionsCharacter {
    /// The log's key for a Condition: "condition:<catalog id or custom>/<UUID>", so recently used
    /// Conditions can be found again from the log.
    private func logKey(for condition: CharacterCondition) -> TraitKey {
        TraitKey(.condition, "\(condition.source.catalogID ?? "custom")/\(condition.id.uuidString)")
    }

    /// e.g. "Swooning (Marcus Vale)" or "Tempted −2".
    package func logName(for condition: CharacterCondition) -> String {
        let title = condition.name(in: conditionCatalog).isEmpty ? "" : condition.titleWithCounter(in: conditionCatalog)
        return condition.note.isEmpty ? title : "\(title) (\(condition.note))"
    }

    /// The Condition a log entry is about, if it's still on the character.
    package func condition(for change: TraitChange) -> CharacterCondition? {
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
    package func canAdd(_ entry: ConditionEntry) -> Bool {
        entry.repeatable || !conditions.contains { $0.source == .catalog(entry.id) }
    }

    package func addCondition(_ condition: CharacterCondition, at date: Date = .now) {
        if condition.hasCounter(in: conditionCatalog) && condition.counter == 0 {
            condition.counter = 1
        }
        conditions.append(condition)
        logCondition(condition, .added, at: date)
    }

    /// Removes the Condition without a Beat, e.g. when it fades or the Storyteller ends it.
    package func endCondition(_ condition: CharacterCondition, at date: Date = .now) {
        conditions.removeAll { $0.id == condition.id }
        logCondition(condition, .ended, at: date)
    }

    /// Removes the Condition, with a Beat unless it says resolving it gives none.
    package func resolveCondition(_ condition: CharacterCondition, at date: Date = .now) {
        conditions.removeAll { $0.id == condition.id }
        let beats = condition.givesBeatOnResolve(in: conditionCatalog) ? 1 : 0
        if beats > 0 { incrementBeats() }
        logCondition(condition, .resolved, beats: beats, at: date)
    }

    /// A Beat for meeting the Condition's Beat while it lasts. The Condition stays.
    package func takeBeat(from condition: CharacterCondition, at date: Date = .now) {
        incrementBeats()
        logCondition(condition, .beat, beats: 1, at: date)
    }

    /// Catalog Conditions added most recently first, each once.
    package func recentConditionIDs(limit: Int = 5) -> [CatalogEntryID] {
        var seen = Set<CatalogEntryID>()
        var ids: [CatalogEntryID] = []
        for change in changeLog.reversed() where change.trait.kind == .condition && change.event == .added {
            let id = String(change.trait.id.prefix { $0 != "/" })
            guard id != "custom", conditionCatalog.entry(id) != nil, seen.insert(id).inserted else { continue }
            ids.append(id)
            if ids.count == limit { break }
        }
        return ids
    }

    /// What active Conditions do to a trait, e.g. "Deprived: −1 to dice pools using Stamina…", one line each.
    package func conditionEffects(on target: ConditionTarget) -> [(condition: CharacterCondition, text: String)] {
        conditions.flatMap { condition in
            (condition.entry(in: conditionCatalog)?.affects ?? []).filter { $0.targets.contains(target) }.map { (condition, $0.text) }
        }
    }
}
