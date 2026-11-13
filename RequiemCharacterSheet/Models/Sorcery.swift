//
//  Sorcery.swift
//  RequiemCharacterSheet
//

import Foundation
import Observation
#if SWIFT_PACKAGE
import ChroniclesCore
#endif

/// One of a character's Crúac rites or Theban miracles: a catalog entry, or a custom one with its own dots.
@Observable
final class Ritual: Identifiable, Codable {
    let id: UUID
    var source: TraitSource
    /// For a custom ritual: the Ritual Discipline that casts it.
    var customDiscipline: TraitSource
    /// For a custom ritual: its dots.
    var customDots: Int

    /// The catalog entry, if this isn't a custom ritual.
    var entry: RitualEntry? {
        source.catalogID.flatMap { Catalog.bundled.rituals.entry($0) }
    }

    /// The name shown on the sheet. Setting it links to the catalog entry with that name, if there is one.
    var name: String {
        get { Catalog.bundled.rituals.name(of: source) }
        set { source = Catalog.bundled.rituals.source(named: newValue) }
    }

    /// The Ritual Discipline that casts it, e.g. Crúac.
    var discipline: TraitSource {
        entry.map { .catalog($0.discipline) } ?? customDiscipline
    }

    var dots: Int {
        entry?.dots ?? customDots
    }

    enum CodingKeys: CodingKey {
        case id, source, customDiscipline, customDots
    }

    init(id: UUID = UUID(), source: TraitSource, customDiscipline: TraitSource = .custom(""), customDots: Int = 1) {
        self.id = id
        self.source = source
        self.customDiscipline = customDiscipline
        self.customDots = customDots
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        try container.encode(customDiscipline, forKey: .customDiscipline)
        try container.encode(customDots, forKey: .customDots)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        source = try container.decodeTraitSource(.source, in: Catalog.bundled.rituals)
        customDiscipline = try container.decodeTraitSource(.customDiscipline, in: Catalog.bundled.disciplines)
        customDots = try container.decode(.customDots, default: 1)
    }
}

/// One of a character's Devotions: a catalog entry, or a custom one with its own Experience cost.
@Observable
final class Devotion: Identifiable, Codable {
    let id: UUID
    var source: TraitSource
    /// For a custom Devotion: what it cost to learn.
    var customExperienceCost: Int

    /// The catalog entry, if this isn't a custom Devotion.
    var entry: DevotionEntry? {
        source.catalogID.flatMap { Catalog.bundled.devotions.entry($0) }
    }

    /// The name shown on the sheet. Setting it links to the catalog entry with that name, if there is one.
    var name: String {
        get { Catalog.bundled.devotions.name(of: source) }
        set { source = Catalog.bundled.devotions.source(named: newValue) }
    }

    /// Experiences needed to learn it.
    var experienceCost: Int {
        entry?.experienceCost ?? customExperienceCost
    }

    enum CodingKeys: CodingKey {
        case id, source, customExperienceCost
    }

    init(id: UUID = UUID(), source: TraitSource, customExperienceCost: Int = 1) {
        self.id = id
        self.source = source
        self.customExperienceCost = customExperienceCost
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        try container.encode(customExperienceCost, forKey: .customExperienceCost)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        source = try container.decodeTraitSource(.source, in: Catalog.bundled.devotions)
        customExperienceCost = try container.decode(.customExperienceCost, default: 1)
    }
}

/// A character's dots in one Mystery's Coil, e.g. three tiers of the Coil of the Ascendant.
@Observable
final class Coil: Identifiable, Codable {
    static let maxRating = 5

    let id: UUID
    /// The Mystery whose Coil this is.
    var mystery: TraitSource
    var rating: Int

    /// The catalog entry, if this isn't a custom Mystery.
    var entry: MysteryEntry? {
        mystery.catalogID.flatMap { Catalog.bundled.mysteries.entry($0) }
    }

    /// The Mystery's name. Setting it links to the catalog entry with that name, if there is one.
    var name: String {
        get { Catalog.bundled.mysteries.name(of: mystery) }
        set { mystery = Catalog.bundled.mysteries.source(named: newValue) }
    }

    /// The tiers learned so far, lowest first.
    var learnedTiers: [CoilTier] {
        entry?.tiers.filter { $0.dots <= rating } ?? []
    }

    enum CodingKeys: CodingKey {
        case id, mystery, rating
    }

    init(id: UUID = UUID(), mystery: TraitSource, rating: Int = 0) {
        self.id = id
        self.mystery = mystery
        self.rating = rating
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mystery, forKey: .mystery)
        try container.encode(rating, forKey: .rating)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        mystery = try container.decodeTraitSource(.mystery, in: Catalog.bundled.mysteries)
        rating = min(max(try container.decode(.rating, default: 0), 0), Coil.maxRating)
    }
}

/// One of a character's Scales: a catalog entry or a custom one.
@Observable
final class Scale: Identifiable, Codable {
    let id: UUID
    var source: TraitSource

    /// The catalog entry, if this isn't a custom Scale.
    var entry: ScaleEntry? {
        source.catalogID.flatMap { Catalog.bundled.scales.entry($0) }
    }

    /// The name shown on the sheet. Setting it links to the catalog entry with that name, if there is one.
    var name: String {
        get { Catalog.bundled.scales.name(of: source) }
        set { source = Catalog.bundled.scales.source(named: newValue) }
    }

    enum CodingKeys: CodingKey {
        case id, source
    }

    init(id: UUID = UUID(), source: TraitSource) {
        self.id = id
        self.source = source
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        source = try container.decodeTraitSource(.source, in: Catalog.bundled.scales)
    }
}
