//
//  CatalogTests.swift
//  RequiemCharacterSheetTests
//

import Foundation
import Testing
@testable import RequiemCharacterSheet

/// The bundled catalogs load completely, their cross-references resolve, and characters link to them.
@MainActor
struct CatalogTests {
    private let catalog = Catalog.bundled

    // MARK: - Bundled data

    @Test func bundledCatalogsLoad() {
        #expect(Set(catalog.books.map(\.id)) == ["vtr2e-core", "cofd-core", "thousand-years-of-night", "dark-eras-companion", "dark-eras", "dark-eras-2", "secrets-of-the-covenants"])
        #expect(catalog.disciplines.all.count == 15)
        #expect(catalog.bloodlines.all.count == 2)
        // 85 from Vampire: The Requiem, 72 from Chronicles of Darkness that Requiem doesn't reprint,
        // 60 from Secrets of the Covenants, 19 from A Thousand Years of Night, 2 from Dark Eras and 3 from Dark Eras 2
        #expect(catalog.merits.all.count == 241)
        #expect(catalog.banes.all.count == 14)
        #expect(catalog.clans.all.count == 9)
        #expect(catalog.covenants.all.count == 10)
        #expect(catalog.rituals.all.count == 54)
        #expect(catalog.devotions.all.count == 40)
        #expect(catalog.mysteries.all.count == 6)
        #expect(catalog.scales.all.count == 16)
        #expect(catalog.elderBanes.all.count == 5)
    }

    @Test func requiemEntriesTakePrecedenceOverReprints() {
        // Fleet of Foot is in both books; the Requiem version wins
        #expect(catalog.merits.entry("fleet-of-foot")?.source.book == "vtr2e-core")
        #expect(catalog.merits.entry("defensive-combat")?.source == SourceReference(book: "cofd-core", page: 61))
    }

    @Test func everyClanBaneStartsAtHumanitySix() {
        #expect(catalog.clans.all.allSatisfy { $0.bane.humanityThreshold == 6 })
    }

    @Test func covenantsCitePages() {
        #expect(catalog.covenants.all.allSatisfy { $0.source.page != nil })
    }

    @Test func everyEntryCitesALoadedBook() {
        let books = Set(catalog.books.map(\.id))
        let sources = catalog.disciplines.all.map(\.source) + catalog.merits.all.map(\.source)
            + catalog.banes.all.map(\.source) + catalog.clans.all.map(\.source) + catalog.covenants.all.map(\.source)
            + catalog.rituals.all.map(\.source) + catalog.devotions.all.map(\.source)
            + catalog.mysteries.all.map(\.source) + catalog.scales.all.map(\.source)
            + catalog.elderBanes.all.map(\.source)
        #expect(sources.allSatisfy { books.contains($0.book) })
    }

    @Test func disciplinesCoverEveryDot() {
        for discipline in catalog.disciplines.all {
            switch discipline.kind {
            case .powers:
                #expect(discipline.powers.map(\.dots) == (1...5).map { $0...$0 }, "\(discipline.name)")
            case .scaling:
                #expect(discipline.powers.map(\.dots) == [1...5], "\(discipline.name)")
            case .ritual:
                #expect(discipline.powers.isEmpty, "\(discipline.name)")
                #expect(discipline.ritualRules != nil, "\(discipline.name)")
            }
        }
    }

    @Test func dicePoolsUseKnownSkills() {
        let skills = catalog.disciplines.all.flatMap(\.powers).compactMap { $0.dicePool?.skill }
        #expect(!skills.isEmpty)
        #expect(skills.allSatisfy { SkillDefinition.withID($0) != nil })
    }

    @Test func clansReferenceCatalogDisciplines() {
        for clan in catalog.clans.all {
            #expect(clan.favoredAttributes.count == 2, "\(clan.name)")
            #expect(clan.disciplines.count == 3, "\(clan.name)")
            #expect(clan.disciplines.allSatisfy { catalog.disciplines.entry($0) != nil }, "\(clan.name)")
        }
        #expect(catalog.clans.entry("akhud")?.disciplines.contains("praestantia") == true)
    }

    @Test func meritPrerequisitesReferenceKnownTraits() {
        let prerequisites = catalog.merits.all.flatMap { $0.prerequisites + $0.prerequisitesAnyOf.flatMap { $0 } }
        for prerequisite in prerequisites {
            let id = prerequisite.id ?? ""
            switch prerequisite.kind {
            case .attribute:
                #expect(AttributeKind(rawValue: id) != nil, "attribute \(id)")
            case .skill:
                #expect(SkillDefinition.withID(SkillID(id)) != nil, "skill \(id)")
            case .merit:
                #expect(catalog.merits.entry(id) != nil, "merit \(id)")
            case .discipline:
                #expect(catalog.disciplines.entry(id) != nil, "discipline \(id)")
            case .covenant, .notCovenant:
                #expect(catalog.covenants.entry(id) != nil, "covenant \(id)")
            case .clan:
                #expect(catalog.clans.entry(id) != nil, "clan \(id)")
            case .bloodPotency, .willpower, .other:
                break
            }
        }
    }

    @Test func secretsOfTheCovenantsIsLoaded() throws {
        let book = "secrets-of-the-covenants"
        #expect(catalog.book(book)?.name == "Secrets of the Covenants")
        #expect(catalog.merits.all.filter { $0.source.book == book }.count == 60)
        #expect(catalog.rituals.all.filter { $0.source.book == book }.count == 28)
        #expect(catalog.scales.all.filter { $0.source.book == book }.count == 4)
        #expect(catalog.conditions.all.filter { $0.source.book == book }.count == 3)
        // Every entry cites a page of the appendix
        #expect(catalog.merits.all.filter { $0.source.book == book }.allSatisfy { (177...202).contains($0.source.page ?? 0) })
        // Its Coils have no Mystery to follow
        #expect(catalog.mysteries.all.filter { $0.coilOnly && $0.source.book == book }.map(\.id).sorted() == ["coil-of-zirnitra", "coil-of-ziva"])
        // Scales point at real Coil tiers
        for scale in catalog.scales.all {
            for coil in scale.prerequisiteCoils {
                #expect(catalog.mysteries.entry(coil.mystery)?.tiers.contains { $0.id == coil.tier } == true, "\(scale.name)")
            }
        }
    }

    @Test func aThousandYearsOfNightIsLoaded() throws {
        let book = "thousand-years-of-night"
        #expect(catalog.book(book)?.name == "A Thousand Years of Night")
        #expect(catalog.clans.all.filter { $0.source.book == book }.map(\.id) == ["akhud", "hollow-mekhet", "julii", "pijavica"])
        #expect(catalog.merits.all.filter { $0.source.book == book }.count == 19)
        #expect(catalog.devotions.all.filter { $0.source.book == book }.count == 11)
        #expect(catalog.rituals.all.filter { $0.source.book == book }.count == 6)
        #expect(catalog.conditions.all.filter { $0.source.book == book }.count == 15)
        #expect(catalog.archetypes.all.filter { $0.source.book == book }.count == 3)
        // Its Leveraged is a different Condition from the Chronicles of Darkness one
        #expect(catalog.conditions.entry("leveraged")?.source.book == "cofd-core")
        #expect(catalog.conditions.entry("leveraged-ghoul")?.source.book == book)
        // The Coil of the Quintessence is learned within the Mystery of the Voivode
        let quintessence = try #require(catalog.mysteries.entry("coil-of-the-quintessence"))
        #expect(quintessence.coilOnly)
        #expect(quintessence.partOfMystery == "mystery-of-the-voivode")
    }

    @Test func pickersGroupEntriesByBook() {
        let clans = CatalogBookSection.sections([CatalogPickerGroup("", catalog.clans.all)])
        #expect(clans.map(\.book.name) == ["Vampire: The Requiem Second Edition", "A Thousand Years of Night"])
        #expect(clans.last?.entries.map(\.id) == ["akhud", "hollow-mekhet", "julii", "pijavica"])
        #expect(clans.allSatisfy { $0.startsBook })

        // Within a book, groups keep their order
        let inClan = catalog.disciplines.all.filter { ["celerity", "praestantia"].contains($0.id) }
        let others = catalog.disciplines.all.filter { ["auspex"].contains($0.id) }
        let disciplines = CatalogBookSection.sections([
            CatalogPickerGroup("In-clan", inClan),
            CatalogPickerGroup("Other", others),
        ])
        #expect(disciplines.map(\.title) == ["In-clan", "Other", "In-clan"])
        #expect(disciplines.map(\.startsBook) == [true, false, true])
        #expect(disciplines.last?.book.id == "thousand-years-of-night")
    }

    @Test func elderBanesDeepenTheFiveClans() {
        #expect(catalog.elderBanes.all.map(\.clan) == ["daeva", "gangrel", "mekhet", "nosferatu", "ventrue"])
        #expect(catalog.elderBanes.all.allSatisfy { $0.humanityThreshold == 3 && catalog.clans.entry($0.clan) != nil })
    }

    @Test func darkErasCovenantsAreLoaded() throws {
        #expect(catalog.book("dark-eras")?.name == "Dark Eras")
        #expect(catalog.covenants.entry("gallows-post")?.source.book == "dark-eras-companion")
        #expect(catalog.covenants.entry("al-hamasoun")?.source.book == "dark-eras-companion")
        #expect(catalog.covenants.entry("weihan-cynn")?.source.book == "dark-eras")
        #expect(catalog.merits.all.filter { $0.source.book == "dark-eras" }.map(\.id) == ["envoy", "contract-with-the-uncanny"])
        // Covenant Status can be taken for any covenant in the catalogs
        let status = try #require(catalog.merits.entry("covenant-status"))
        let options = try #require(Character().qualifierOptions(for: status))
        #expect(["Gallows Post", "Weihan Cynn", "Al-Hamasoun", "Invictus"].allSatisfy(options.contains))
    }

    @Test func gallowsPostTakesCarthianLawsWithItsOwnStatus() throws {
        let laws = catalog.merits.all.filter { $0.group == "carthian-law" }.map(\.id)
        #expect(laws.count == 12)
        #expect(laws.contains("stare-decisis") && laws.contains("lex-terrae"))

        let lexTerrae = try #require(catalog.merits.entry("lex-terrae"))
        let carthianPull = try #require(catalog.merits.entry("carthian-pull"))
        let character = Character()
        character.covenantSource = .catalog("gallows-post")
        character.merits.append(Merit(source: .catalog("feeding-grounds"), rating: 1))
        character.merits.append(Merit(source: .catalog("covenant-status"), qualifier: "Gallows Post", rating: 1))
        #expect(character.unmetPrerequisites(for: lexTerrae).map(\.description) == ["Gallows Post Status 2"])
        character.merits[1].rating = 2
        #expect(character.unmetPrerequisites(for: lexTerrae).isEmpty)
        // Carthian Merits that aren't Laws still need Carthian Status
        #expect(character.unmetPrerequisites(for: carthianPull).map(\.description) == ["Carthian Movement Status 1"])
        // Others still need Carthian Status for the Laws
        character.covenantSource = .catalog("invictus")
        #expect(character.unmetPrerequisites(for: lexTerrae).map(\.description) == ["Carthian Movement Status 2"])
    }

    @Test func historicalCovenantStatusCountsAsAModernOne() throws {
        let character = Character()
        character.covenantSource = .catalog("circles-of-mor")
        character.merits.append(Merit(source: .catalog("covenant-status"), qualifier: "Circles of Mor", rating: 2))
        #expect(character.covenantStatus("circle-of-the-crone") == 2)
        #expect(character.covenantStatus("invictus") == 0)

        let apostle = try #require(catalog.merits.entry("parliaments-apostle"))
        #expect(character.unmetPrerequisites(for: apostle).isEmpty)
        // Merits of the Crone take Circle of Mor Status, and are worded for it
        let crone = try #require(catalog.merits.all.first { merit in
            merit.prerequisites.contains { $0.kind == .covenant && $0.id == "circle-of-the-crone" && ($0.minimum ?? 1) >= 3 }
        })
        #expect(character.unmetPrerequisites(for: crone).contains { $0.description.hasPrefix("Circles of Mor Status") })
    }

    @Test func theBronHaveTheirOwnFavoredAttributes() throws {
        let bron = try #require(catalog.bloodlines.entry("bron"))
        #expect(bron.favoredAttributes == [.stamina, .presence])
        #expect(bron.disciplines.contains("crochan"))
        #expect(catalog.disciplines.entry("crochan")?.powers.count == 5)

        let character = Character()
        character.clan = "Ventrue"
        character.bloodline = "Bron"
        #expect(character.favoredAttributesText == "Presence (Ventrue and Bron), Resolve (Ventrue) or Stamina (Bron)")
    }

    @Test func notBeingInACovenantIsChecked() throws {
        let laity = try #require(catalog.merits.entry("laity"))
        let character = Character()
        character.covenantSource = .catalog("invictus")
        #expect(character.unmetPrerequisites(for: laity).isEmpty)
        character.covenantSource = .catalog("lancea-et-sanctum")
        #expect(character.unmetPrerequisites(for: laity).map(\.description) == ["Not a member of the Lancea et Sanctum"])
    }

    @Test func flockAddsToHerd() throws {
        let character = Character()
        character.merits.append(Merit(source: .catalog("herd"), rating: 4))
        #expect(character.meritBonus(for: "herd") == 0)
        character.merits.append(Merit(source: .catalog("flock"), rating: 3))

        // Above five, as the book allows
        #expect(character.meritBonus(for: "herd") == 3)
        #expect(character.meritBonus(for: "flock") == 0)
    }

    @Test func willpowerRequirementIsChecked() throws {
        let mobilizeOutrage = try #require(catalog.merits.entry("mobilize-outrage"))
        let character = Character()
        character.covenantSource = .catalog("carthian-movement")
        character.merits.append(Merit(source: .catalog("covenant-status"), qualifier: "Carthian Movement", rating: 1))
        character.skill(.brawl)?.rating = 2
        func resolve() -> Attribute? { character.attributes.first { $0.kind == .resolve } }
        func composure() -> Attribute? { character.attributes.first { $0.kind == .composure } }
        resolve()?.rating = 2
        composure()?.rating = 2
        #expect(character.unmetPrerequisites(for: mobilizeOutrage).map(\.description) == ["Willpower 5"])

        composure()?.rating = 3
        #expect(character.unmetPrerequisites(for: mobilizeOutrage).isEmpty)
    }

    @Test func meritsHaveRatings() {
        #expect(catalog.merits.all.allSatisfy { !$0.ratings.isEmpty && $0.ratings.allSatisfy { (1...5).contains($0) } })
    }

    // MARK: - Name matching

    @Test func namesMatchIgnoringCaseAndLeadingThe() {
        #expect(catalog.disciplines.source(named: "vigor") == .catalog("vigor"))
        #expect(catalog.covenants.source(named: "The Invictus") == .catalog("invictus"))
        #expect(catalog.clans.source(named: "akhud") == .catalog("akhud"))
    }

    @Test func partlyTypedNamesStayCustom() {
        // A trailing space means the player is still typing, e.g. "Vigor Boost"
        #expect(catalog.disciplines.source(named: "Vigor ") == .custom("Vigor "))
        #expect(catalog.disciplines.source(named: "Blood Sorcery") == .custom("Blood Sorcery"))
    }

    @Test func meritQualifiersAreParsed() {
        let language = Merit(name: "Language (French)", rating: 1)
        #expect(language.source == .catalog("language"))
        #expect(language.qualifier == "French")
        #expect(language.name == "Language (French)")

        // From the Chronicles of Darkness catalog
        let defensiveCombat = Merit(name: "Defensive Combat (Brawl)", rating: 1)
        #expect(defensiveCombat.source == .catalog("defensive-combat"))
        #expect(defensiveCombat.qualifier == "Brawl")

        let homebrew = Merit(name: "Homebrew Merit (Variant)", rating: 1)
        #expect(homebrew.source == .custom("Homebrew Merit (Variant)"))
        #expect(homebrew.qualifier == nil)
    }

    @Test func typingANameLinksToTheCatalog() {
        let discipline = Discipline()
        discipline.name = "Praestantia"
        #expect(discipline.entry?.id == "praestantia")

        let character = Character()
        character.clan = "Daeva"
        #expect(character.clanEntry?.bane.name == "The Wanton Curse")
    }

    // MARK: - Saves

    @Test func olderSavesLinkNamesToTheCatalog() throws {
        let character = try JSONDecoder().decode(Character.self, from: Data("""
        {
          "schemaVersion": 4,
          "clan": "Akhud",
          "covenant": "Ordo Dracul",
          "disciplines": [{"name": "Vigor", "rating": 2}, {"name": "Homebrew Power", "rating": 1}],
          "merits": [{"name": "Language (French)", "rating": 1}, {"name": "Defensive Combat (Brawl)", "rating": 1}],
          "banes": [{"text": "Bells"}, {"text": "Cannot cross running water"}]
        }
        """.utf8))

        #expect(character.clanSource == .catalog("akhud"))
        #expect(character.covenantSource == .catalog("ordo-dracul"))
        #expect(character.disciplines.map(\.source) == [.catalog("vigor"), .custom("Homebrew Power")])
        #expect(character.disciplines.map(\.rating) == [2, 1])
        #expect(character.merits.map(\.source) == [.catalog("language"), .catalog("defensive-combat")])
        #expect(character.merits.map(\.qualifier) == ["French", "Brawl"])
        #expect(character.banes.map(\.source) == [.catalog("bells"), .custom("Cannot cross running water")])

        // Rules that still match by name keep working
        #expect(character.hasDefensiveCombatBrawl)
        #expect(character.attributeBonus(for: .strength) == 2)
    }

    @Test func traitSourcesAreSaved() throws {
        let character = Character()
        character.clan = "Mekhet"
        character.covenant = "Homebrew Covenant"
        character.disciplines = [Discipline(name: "Auspex", rating: 3)]
        character.merits = [Merit(name: "Status (Harpies)", rating: 2)]

        let data = try JSONEncoder().encode(character)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let disciplines = try #require(json["disciplines"] as? [[String: Any]])
        let merits = try #require(json["merits"] as? [[String: Any]])

        #expect(json["schemaVersion"] as? Int == 10)
        #expect((json["clan"] as? [String: String]) == ["catalog": "mekhet"])
        #expect((json["covenant"] as? [String: String]) == ["custom": "Homebrew Covenant"])
        #expect((disciplines.first?["source"] as? [String: String]) == ["catalog": "auspex"])
        #expect(disciplines.first?["name"] == nil)
        #expect(merits.first?["qualifier"] as? String == "Harpies")

        let reloaded = try JSONDecoder().decode(Character.self, from: data)
        #expect(reloaded.clan == "Mekhet")
        #expect(reloaded.covenant == "Homebrew Covenant")
        #expect(reloaded.disciplines.first?.name == "Auspex")
        #expect(reloaded.merits.first?.name == "Status (Harpies)")
    }

    @Test func unknownCatalogIDsAreKept() throws {
        let character = try JSONDecoder().decode(Character.self, from: Data("""
        {"disciplines": [{"source": {"catalog": "some-future-discipline"}, "rating": 2}]}
        """.utf8))

        #expect(character.disciplines.first?.name == "some-future-discipline")
        let reloaded = try JSONDecoder().decode(Character.self, from: JSONEncoder().encode(character))
        #expect(reloaded.disciplines.first?.source == .catalog("some-future-discipline"))
    }
}
