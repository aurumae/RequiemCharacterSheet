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

extension Character: ConditionsCharacter {
    var conditionCatalog: CatalogIndex<ConditionEntry> {
        Catalog.bundled.conditions
    }
}
