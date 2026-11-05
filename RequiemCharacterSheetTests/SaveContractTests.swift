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
