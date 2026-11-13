//
//  MeritCatalog.swift
//  RequiemCharacterSheet
//

import Foundation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

/// A Merit looked up in the bundled catalogs.
extension Merit {
    /// The catalog entry, if this isn't a custom Merit.
    var entry: MeritEntry? {
        entry(in: Catalog.bundled.merits)
    }

    /// The name shown on the sheet, e.g. "Language (French)". Setting it links to the catalog entry
    /// with that name, reading a trailing "(…)" as the qualifier.
    var name: String {
        get { name(in: Catalog.bundled.merits) }
        set { (source, qualifier) = Self.parse(newValue, in: Catalog.bundled.merits) }
    }

    convenience init(id: UUID = UUID(), name: String = "", rating: Int = 0) {
        let (source, qualifier) = Self.parse(name, in: Catalog.bundled.merits)
        self.init(id: id, source: source, qualifier: qualifier, rating: rating)
    }
}
