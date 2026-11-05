import Foundation
import Testing
@testable import RequiemCharacterSheet

private final class FixtureBundleMarker: NSObject {}

enum SaveFixtures {
    static func data(_ name: String) throws -> Data { try resource("characters/" + name) }

    static func resource(_ name: String) throws -> Data {
        #if SWIFT_PACKAGE
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("shared/fixtures")
        #else
        let resources = try #require(Bundle(for: FixtureBundleMarker.self).resourceURL)
        let directory = resources.appendingPathComponent("fixtures")
        #endif
        return try Data(contentsOf: directory.appendingPathComponent(name + ".json"))
    }
}

@MainActor
struct SaveContractTests {
    private static let current = ["v9-advanced", "v9-guided"]
    private static let historical = ["v6-clan-bane", "v7-sorcery", "v8-paid", "v9-early-guided"]
    private static let exchange = ProcessInfo.processInfo.environment["REQUIEM_EXCHANGE_DIR"]
    private let encoder = JSONEncoder()

    @Test func staminaAdvancementMatchesThePhoneEditor() throws {
        struct Step: Decodable {
            let delta, rating, cost, available: Int
            let xpMode: Bool
            let paidLevels: [Int]
        }
        let steps = try JSONDecoder().decode([Step].self, from: SaveFixtures.resource("stamina-advancement"))
        var character = Character()
        for (index, step) in steps.enumerated() {
            character.xpMode = step.xpMode
            let before = character.traitSnapshot
            let stamina = try #require(character.attributes.first { $0.kind == .stamina })
            stamina.rating += step.delta
            character.recordChanges(since: before)
            character = try JSONDecoder().decode(Character.self, from: encoder.encode(character))
            #expect(character.rating(of: .stamina) == step.rating)
            #expect(character.changeLog.count == index + 1)
            #expect(character.changeLog.last?.experiences == step.cost)
            #expect(character.experiencesAvailable == step.available)
            let paid = character.paidDots[TraitKey(.attribute, "stamina")] ?? [:]
            #expect(paid.keys.sorted() == step.paidLevels)
        }
    }

    @Test func coreAdvancementMatchesThePhoneEditor() throws {
        struct Step: Decodable {
            let kind, id: String
            let rating, cost: Int?
            let specialties: [String]?
            let xpMode: Bool
            let available: Int
            let paidLevels: [Int]
        }
        let steps = try JSONDecoder().decode([Step].self, from: SaveFixtures.resource("core-advancement"))
        var character = Character()
        var costs: [Int] = []
        for step in steps {
            character.xpMode = step.xpMode
            let before = character.traitSnapshot
            switch step.kind {
            case "attribute":
                let attribute = try #require(character.attributes.first { $0.kind.rawValue == step.id })
                attribute.rating = try #require(step.rating)
            case "skill":
                let skill = try #require(character.skills.first { $0.skillID.rawValue == step.id })
                skill.rating = try #require(step.rating)
            default:
                let skill = try #require(character.skills.first { $0.skillID.rawValue == step.id })
                skill.specialties = try #require(step.specialties)
            }
            character.recordChanges(since: before)
            character = try JSONDecoder().decode(Character.self, from: encoder.encode(character))
            if let cost = step.cost { costs.append(cost) }
            #expect(character.changeLog.map(\.experiences) == costs)
            #expect(character.experiencesAvailable == step.available)
            let key = TraitKey(try #require(TraitKind(rawValue: step.kind)), step.id)
            #expect((character.paidDots[key] ?? [:]).keys.sorted() == step.paidLevels)
        }
    }

    @Test func ordinaryPlayMatchesThePhoneEditor() throws {
        struct Step: Decodable {
            let action: String
            let kind, source, text, field: String?
            let row, rating, value, index, health: Int?
            let enabled: Bool?
            let costs: [Int]
            let available: Int
        }
        let steps = try JSONDecoder().decode([Step].self, from: SaveFixtures.resource("ordinary-play"))
        var character = Character()
        var expectedCosts: [Int] = []
        var rowIDs: [Int: UUID] = [:]
        for (index, step) in steps.enumerated() {
            let row = step.row ?? 0
            let id = rowIDs[row] ?? UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", row))!
            let before = character.traitSnapshot
            switch step.action {
            case "clan": character.clan = step.text!
            case "xp": character.xpMode = step.enabled!
            case "add":
                let source = TraitSource.catalog(step.source!)
                switch step.kind {
                case "Discipline": character.disciplines.append(Discipline(id: id, source: source, rating: 1))
                case "Merit": character.merits.append(Merit(id: id, source: source, rating: Catalog.bundled.merits.entry(step.source!)?.ratings.min() ?? 1))
                case "Ritual": character.rituals.append(Ritual(id: id, source: source))
                case "Scale": character.scales.append(Scale(id: id, source: source))
                default: Issue.record("Unsupported shared addition")
                }
            case "remove":
                switch step.kind {
                case "Discipline": character.disciplines.removeAll { $0.id == id }
                case "Merit": character.merits.removeAll { $0.id == id }
                case "Ritual": character.rituals.removeAll { $0.id == id }
                case "Devotion": character.devotions.removeAll { $0.id == id }
                case "Scale": character.scales.removeAll { $0.id == id }
                default: Issue.record("Unsupported shared removal")
                }
            case "rate":
                switch step.kind {
                case "Discipline": try #require(character.disciplines.first { $0.id == id }).rating = step.rating!
                case "Merit":
                    let merit = try #require(character.merits.first { $0.id == id })
                    merit.rating = merit.entry?.allowedRating(for: step.rating!) ?? step.rating!
                case "Coil": try #require(character.coils.first { $0.id == id }).rating = step.rating!
                default: Issue.record("Unsupported shared rating")
                }
            case "healthMark": character.setHealthBox(at: step.index!, to: .bashing)
            case "mystery":
                character.chooseMystery(.catalog(step.source!))
                rowIDs[row] = try #require(character.coils.first { $0.mystery == .catalog(step.source!) }).id
            case "number":
                if step.field == "Humanity" { character.humanity = step.value! }
                else { character.bloodPotency = step.value! }
            case "customDevotion": character.devotions.append(Devotion(id: id, source: .custom(step.text!), customExperienceCost: step.value!))
            case "devotionCost": try #require(character.devotions.first { $0.id == id }).customExperienceCost = step.value!
            case "rename": try #require(character.devotions.first { $0.id == id }).name = step.text!
            default: Issue.record("Unsupported shared action")
            }
            character.recordChanges(since: before, at: Date(timeIntervalSinceReferenceDate: 800_000_000.25 + Double(index)))
            character = try JSONDecoder().decode(Character.self, from: encoder.encode(character))
            expectedCosts += step.costs
            #expect(character.changeLog.map(\.experiences) == expectedCosts)
            #expect(character.experiencesAvailable == step.available)
            if let health = step.health { #expect(character.health == health) }
        }
        #expect(character.experiencesAvailable == -31)
        #expect(character.healthBoxes.allSatisfy { $0 == .none })
        if let path = Self.exchange {
            try encoder.encode(character).write(to: URL(fileURLWithPath: path).appendingPathComponent("swift-ordinary-play.json"))
        }
    }

    @Test func readsKotlinOrdinaryPlay() throws {
        guard ProcessInfo.processInfo.environment["REQUIEM_CHECK_KOTLIN"] == "1", let path = Self.exchange else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: path).appendingPathComponent("kotlin-ordinary-play.json"))
        let c = try JSONDecoder().decode(Character.self, from: data)
        #expect(c.experiencesAvailable == -31)
        #expect(c.humanity == 5 && c.bloodPotency == 1)
        #expect(c.disciplineRating("cruac") == 2)
        #expect(c.coilRating("mystery-of-the-wyrm") == 2)
        #expect(c.rituals.count == 2 && c.scales.count == 1)
        #expect(c.healthBoxes.allSatisfy { $0 == .none })
        #expect(try object(encoder.encode(c)) == object(data))
    }

    @Test func currentFixturesMatchWhatSwiftWrites() throws {
        if let path = Self.exchange {
            let c = Catalog.bundled
            let ids = ["books": c.books.map(\.id), "disciplines": c.disciplines.all.map(\.id),
                       "merits": c.merits.all.map(\.id), "clans": c.clans.all.map(\.id),
                       "covenants": c.covenants.all.map(\.id), "banes": c.banes.all.map(\.id),
                       "rituals": c.rituals.all.map(\.id), "devotions": c.devotions.all.map(\.id),
                       "mysteries": c.mysteries.all.map(\.id), "scales": c.scales.all.map(\.id),
                       "archetypes": c.archetypes.all.map(\.id)]
            let url = URL(fileURLWithPath: path).appendingPathComponent("catalog-ids.json")
            try encoder.encode(ids).write(to: url)
        }
        for name in Self.current {
            let data = try SaveFixtures.data(name)
            let character = try JSONDecoder().decode(Character.self, from: data)
            let written = try encoder.encode(character)
            #expect(try object(written) == object(data))
            if let path = Self.exchange {
                let url = URL(fileURLWithPath: path).appendingPathComponent("swift-" + name + ".json")
                try written.write(to: url)
            }
        }
    }

    @Test func sharedExamplesAgreeOnDerivedValues() throws {
        struct Expected: Decodable {
            let health, willpower, availableXP: Int
            let guided: Bool
        }
        let cases = try JSONDecoder().decode([String: Expected].self, from: SaveFixtures.resource("expected-values"))
        for (name, expected) in cases {
            let character = try JSONDecoder().decode(Character.self, from: SaveFixtures.data(name))
            #expect(character.health == expected.health)
            #expect(character.willpower == expected.willpower)
            #expect(character.experiencesAvailable == expected.availableXP)
            #expect(character.isInCreation == expected.guided)
        }
    }

    @Test func historicalAndFutureFilesRespectTheStoreBoundary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CharacterStore(directory: directory)
        for name in Self.historical {
            let data = try SaveFixtures.data(name)
            let id = try JSONDecoder().decode(Character.self, from: data).id
            let url = directory.appendingPathComponent(id.uuidString + ".json")
            try data.write(to: url)
            let character = try store.load(id)
            let modified = character.modifiedAt
            #expect(try store.save(character) == false)
            #expect(character.modifiedAt == modified)
            #expect(try Data(contentsOf: url) == data)
            if name == "v7-sorcery" {
                #expect(character.rituals.count == 2)
                #expect(character.experiencesAvailable == character.experiences)
            }
            if name == "v9-early-guided" {
                #expect(character.creation?.attributePriorities == [:])
                #expect(character.creation?.favoredAttribute == nil)
            }
        }
        let future = try SaveFixtures.data("v10-future")
        let id = UUID()
        let url = directory.appendingPathComponent(id.uuidString + ".json")
        try future.write(to: url)
        #expect(throws: CharacterStoreError.newerFormat(version: 10)) { try store.load(id) }
        #expect(try Data(contentsOf: url) == future)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["REQUIEM_CHECK_KOTLIN"] == "1"))
    func readsKotlinEdits() throws {
        let path = try #require(Self.exchange)
        let blankFile = try Data(contentsOf: URL(fileURLWithPath: path).appendingPathComponent("kotlin-blank.json"))
        let blank = try JSONDecoder().decode(Character.self, from: blankFile)
        // Java may print a Double in scientific notation. Compare dates as Foundation seconds.
        struct Timestamps: Decodable { let createdAt, modifiedAt: Double }
        let timestamps = try JSONDecoder().decode(Timestamps.self, from: blankFile)
        #expect(timestamps.createdAt == blank.createdAt.timeIntervalSinceReferenceDate)
        #expect(timestamps.modifiedAt == blank.modifiedAt.timeIntervalSinceReferenceDate)
        func withoutDates(_ data: Data) throws -> [String: Any] {
            var fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            for key in ["createdAt", "modifiedAt"] { fields.removeValue(forKey: key) }
            return fields
        }
        #expect(try NSDictionary(dictionary: withoutDates(blankFile)) == NSDictionary(dictionary: withoutDates(encoder.encode(blank))))
        #expect(blank.createdAt == blank.modifiedAt)
        // New sheets pick their own UUIDs and dates. All other defaults must match the iOS constructor.
        func defaults(_ data: Data) throws -> NSDictionary {
            var fields = try withoutDates(data)
            fields.removeValue(forKey: "id")
            for key in ["touchstones", "aspirations"] {
                let rows = try #require(fields[key] as? [[String: Any]])
                fields[key] = rows.map { $0.filter { $0.key != "id" } }
            }
            return fields as NSDictionary
        }
        #expect(try defaults(blankFile) == defaults(encoder.encode(Character())))
        for name in Self.current + Self.historical {
            let url = URL(fileURLWithPath: path).appendingPathComponent("kotlin-" + name + ".json")
            let file = try Data(contentsOf: url)
            let actual = try JSONDecoder().decode(Character.self, from: file)
            let expected = try JSONDecoder().decode(Character.self, from: SaveFixtures.data(name))
            expected.name += " (edited on Android)"
            expected.modifiedAt = Date(timeIntervalSinceReferenceDate: 800_000_002.875)
            #expect(try object(file) == object(encoder.encode(expected)))
            #expect(try object(encoder.encode(actual)) == object(encoder.encode(expected)))
        }
    }

    private func object(_ data: Data) throws -> NSDictionary {
        try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }
}
