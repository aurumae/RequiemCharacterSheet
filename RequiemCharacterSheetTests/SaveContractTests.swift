import Foundation
import Testing
@testable import RequiemCharacterSheet
#if SWIFT_PACKAGE
@testable import ChroniclesCore
#endif

private final class FixtureBundleMarker: NSObject {}

enum SaveFixtures {
    struct Contract: Decodable {
        struct Platform: Decodable {
            let readSchema: Int
            let catalogKinds, capabilities: [String]
            let writers: [String: Int]
        }
        struct Scenario: Decodable { let schema: Int?; let requires, roles: [String] }
        let platforms: [String: Platform]
        let scenarios: [String: Scenario]
    }
    struct Plan: Decodable { let scenarios, catalogKinds: [String] }
    // Missing or malformed metadata is a hard test failure, never an empty selection.
    static let contract = try! JSONDecoder().decode(Contract.self, from: resource("contracts"))
    static let plan: Plan? = ProcessInfo.processInfo.environment["REQUIEM_EXCHANGE_PLAN"].map {
        try! JSONDecoder().decode(Plan.self, from: Data(contentsOf: URL(fileURLWithPath: $0)))
    }
    static func supported(_ scenario: Contract.Scenario, by platform: Contract.Platform) -> Bool {
        (scenario.schema ?? 1) <= platform.readSchema && Set(scenario.requires).isSubset(of: Set(platform.capabilities))
    }
    static func names(_ role: String) -> [String] {
        contract.scenarios.filter { $0.value.roles.contains(role) && supported($0.value, by: contract.platforms["ios"]!) }
            .keys.sorted().map { $0.replacingOccurrences(of: "characters/", with: "").replacingOccurrences(of: ".json", with: "") }
    }
    static func selected(_ scenario: String) -> Bool {
        plan?.scenarios.contains(scenario) ?? contract.platforms.values.allSatisfy { supported(contract.scenarios[scenario]!, by: $0) }
    }
    static func exchange(_ scenario: String) -> String? {
        selected(scenario) ? ProcessInfo.processInfo.environment["REQUIEM_EXCHANGE_DIR"] : nil
    }
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
    private static var current: [String] { SaveFixtures.names("current") }
    private static var historical: [String] { SaveFixtures.names("historical") }
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
        if let path = SaveFixtures.exchange("ordinary-play.json") {
            try encoder.encode(character).write(to: URL(fileURLWithPath: path).appendingPathComponent("swift-ordinary-play.json"))
        }
    }

    @Test func readsKotlinOrdinaryPlay() throws {
        guard ProcessInfo.processInfo.environment["REQUIEM_CHECK_KOTLIN"] == "1", let path = SaveFixtures.exchange("ordinary-play.json") else { return }
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

    @Test func readsKotlinBeta2Conditions() throws {
        guard ProcessInfo.processInfo.environment["REQUIEM_CHECK_KOTLIN"] == "1", let path = SaveFixtures.exchange("beta2-play") else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: path).appendingPathComponent("kotlin-beta2-play.json"))
        let c = try JSONDecoder().decode(Character.self, from: data)
        #expect(c.beats == 1 && c.experiences == 1)
        #expect(c.conditions.count == 2)
        #expect(c.conditions.first?.name == "Tempted" && c.conditions.first?.counter == 2)
        #expect(c.conditions.last?.name == "Haunted" && c.conditions.last?.isPersistent == true)
        #expect(c.changeLog.filter { $0.event == .beat }.count == 1)
        #expect(c.changeLog.filter { $0.event == .resolved }.first?.beats == 1)
        #expect(c.paidDots.isEmpty)
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
                       "archetypes": c.archetypes.all.map(\.id), "bloodlines": c.bloodlines.all.map(\.id), "conditions": c.conditions.all.map(\.id),
                       "elderBanes": c.elderBanes.all.map(\.id)]
            let url = URL(fileURLWithPath: path).appendingPathComponent("catalog-ids.json")
            try encoder.encode(ids).write(to: url)
        }
        for name in Self.current {
            let data = try SaveFixtures.data(name)
            let character = try JSONDecoder().decode(Character.self, from: data)
            let written = try encoder.encode(character)
            #expect(try object(written) == object(data))
            if let path = SaveFixtures.exchange("characters/\(name).json") {
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
        let future = try JSONSerialization.data(withJSONObject: ["schemaVersion": Character.currentSchemaVersion + 1, "name": "Future save"])
        let id = UUID()
        let url = directory.appendingPathComponent(id.uuidString + ".json")
        try future.write(to: url)
        #expect(throws: CharacterStoreError.newerFormat(version: Character.currentSchemaVersion + 1)) { try store.load(id) }
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
            guard SaveFixtures.selected("characters/\(name).json") else { continue }
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

/// The same edits, refusals and resumable checkpoints as the Android guided editor.
@MainActor
struct GuidedCreationContractTests {
    private let encoder = JSONEncoder()
    private var exchange: String? { SaveFixtures.exchange("guided-creation.json") }
    private func id(_ row: Int) -> UUID { UUID(uuidString: String(format: "30000000-0000-0000-0000-%012d", row))! }
    private struct Step: Decodable {
        let action: String
        let field, text, category, id, kind, source, qualifier, checkpoint: String?
        let value, rating, row, overspend, done, available: Int?
        let skills, anyway, accepted, withinLimits: Bool?
    }

    @Test func guidedCreationMatchesTheAndroidEditor() throws {
        let steps = try JSONDecoder().decode([Step].self, from: SaveFixtures.resource("guided-creation"))
        var c = Character.guided()
        var trace: [[String: Any]] = []
        for (index, s) in steps.enumerated() {
            let before = c.traitSnapshot
            let original = try encoder.encode(c)
            switch s.action {
            case "detail":
                switch s.field {
                case "Name": c.name = s.text!
                case "Clan": c.clan = s.text!
                case "Concept": c.concept = s.text!
                case "Mask": c.mask = s.text!
                case "Dirge": c.dirge = s.text!
                default: Issue.record("Unexpected detail")
                }
            case "priority": c.setPriority(CreationPriority(rawValue: s.value!)!, for: TraitCategory(rawValue: s.category!.lowercased())!, skills: s.skills ?? false)
            case "attribute":
                let kind = AttributeKind(rawValue: s.id!)!
                if s.rating! >= c.minimumRating(of: kind), s.rating! <= c.editableMaximum(for: TraitKey(.attribute, s.id!), upTo: c.baseRatingCap) {
                    c.attributes.first { $0.kind == kind }!.rating = s.rating!
                }
            case "skill":
                if s.rating! <= c.editableMaximum(for: TraitKey(.skill, s.id!), upTo: c.baseRatingCap) {
                    c.skills.first { $0.skillID.rawValue == s.id! }!.rating = s.rating!
                }
            case "specialty": if c.canAddSpecialty { c.skills.first { $0.skillID.rawValue == s.id! }!.specialties.append(s.text!) }
            case "favored": c.chooseFavoredAttribute(AttributeKind(rawValue: s.id!)!)
            case "aspiration":
                if s.row! == 0 { c.aspirations[0].text = s.text! }
                else { c.aspirations.append(Aspiration(id: id(s.row!), text: s.text!)) }
            case "touchstone": c.touchstones.first { $0.level == s.value! }!.text = s.text!
            case "add":
                let source = TraitSource.catalog(s.source!)
                switch s.kind {
                case "Discipline":
                    if c.creationAllows(.discipline(Catalog.bundled.disciplines.entry(s.source!))) { c.disciplines.append(Discipline(id: id(s.row!), source: source, rating: 1)) }
                case "Merit":
                    let entry = Catalog.bundled.merits.entry(s.source!)!
                    let rating = entry.ratings.min() ?? 1
                    if c.creationAllows(.merit(entry, rating: rating)) { c.merits.append(Merit(id: id(s.row!), source: source, qualifier: s.qualifier, rating: rating)) }
                case "Ritual":
                    let entry = Catalog.bundled.rituals.entry(s.source!)!
                    if c.creationAllows(.ritual(discipline: .catalog(entry.discipline), dots: entry.dots)) { c.rituals.append(Ritual(id: id(s.row!), source: source)) }
                case "Devotion": if c.canLearnDevotionsAndScales { c.devotions.append(Devotion(id: id(s.row!), source: source)) }
                case "Scale": if c.canLearnDevotionsAndScales { c.scales.append(Scale(id: id(s.row!), source: source)) }
                default: Issue.record("Unexpected entry")
                }
            case "rate":
                let kind: TraitKind = s.kind == "Discipline" ? .discipline : .merit
                if s.rating! <= c.editableMaximum(for: TraitKey(kind, id(s.row!).uuidString), upTo: 5) {
                    if kind == .discipline { c.disciplines.first { $0.id == id(s.row!) }!.rating = s.rating! }
                    else { c.merits.first { $0.id == id(s.row!) }!.rating = s.rating! }
                }
            case "number":
                let bp = s.field == "BloodPotency"
                if s.value! <= c.editableMaximum(for: TraitKey(bp ? .bloodPotency : .humanity, bp ? "bloodPotency" : "humanity"), upTo: 10) {
                    if bp { c.bloodPotency = s.value! } else { c.humanity = s.value! }
                }
            case "bonus": c.creation?.bonusExperiences = s.value!
            case "finish":
                if c.isInCreation, c.creationReport.isWithinLimits, (s.anyway == true || c.unfinishedCreationSteps.isEmpty) { c.finishCreation(bonusExperiences: c.creation!.bonusExperiences) }
            case "check": break
            default: Issue.record("Unknown creation action")
            }
            c.recordChanges(since: before, at: Date(timeIntervalSinceReferenceDate: 800_000_000.25 + Double(index)))
            if s.accepted == false {
                let old = try JSONSerialization.jsonObject(with: original) as! NSDictionary
                let new = try JSONSerialization.jsonObject(with: encoder.encode(c)) as! NSDictionary
                #expect(old.isEqual(new), "Rejected step \(index)")
            }
            c = try JSONDecoder().decode(Character.self, from: encoder.encode(c))
            if let within = s.withinLimits { #expect(c.creationReport.isWithinLimits == within, "Step \(index)") }
            if let overspend = s.overspend { #expect(c.creationReport.overspend == overspend, "Step \(index)") }
            if let done = s.done { #expect(c.creationSteps.filter { $0.status == .done }.count == done, "Step \(index)") }
            if let available = s.available { #expect(c.experiencesAvailable == available, "Step \(index)") }
            if c.isInCreation { #expect(!c.xpMode); #expect(c.paidDots.isEmpty); #expect(c.changeLog.allSatisfy { $0.duringCreation == true && $0.experiences == 0 }) }
            trace.append(traceRow(c))
            if let checkpoint = s.checkpoint, let exchange {
                try encoder.encode(c).write(to: URL(fileURLWithPath: exchange).appendingPathComponent("swift-guided-\(checkpoint).json"))
            }
        }
        #expect(steps.count == 71)
        #expect(c.experiencesAvailable == 10)
        #expect(c.changeLog.suffix(5).map(\.experiences) == [4, -4, 0, 5, 0])
        if let exchange { try JSONSerialization.data(withJSONObject: trace, options: [.sortedKeys]).write(to: URL(fileURLWithPath: exchange).appendingPathComponent("swift-guided-trace.json")) }
    }

    private func traceRow(_ c: Character) -> [String: Any] {
        var row: [String: Any] = ["attributes": c.attributes.map(\.rating), "skills": c.skills.map(\.rating),
            "available": c.experiencesAvailable, "xpMode": c.xpMode, "costs": c.changeLog.map(\.experiences),
            "creationChanges": c.changeLog.map { $0.duringCreation as Any? ?? NSNull() },
            "favored": c.creation?.favoredAttribute?.rawValue as Any? ?? NSNull(), "bonus": c.creation?.bonusExperiences as Any? ?? NSNull(), "report": NSNull()]
        if c.isInCreation {
            let r = c.creationReport
            func budgets(_ budgets: [TraitCategory: CreationBudget]) -> [[Any]] {
                TraitCategory.allCases.map { category in let b = budgets[category]!; return [b.used, b.allowed, b.priority?.rawValue as Any? ?? NSNull()] }
            }
            row["report"] = ["attributes": budgets(r.attributes), "skills": budgets(r.skills), "specialties": r.specialties.used,
                "disciplines": r.disciplines.used, "merits": r.merits.used, "problems": r.problems.map(\.description).sorted(),
                "steps": c.creationSteps.map { step in switch step.status { case .done: "Done"; case .inProgress: "InProgress"; case .problem: "Problem" } },
                "details": c.creationSteps.map(\.detail)]
        }
        return row
    }

    @Test func readsKotlinGuidedCreation() throws {
        guard ProcessInfo.processInfo.environment["REQUIEM_CHECK_KOTLIN"] == "1", let exchange else { return }
        for checkpoint in ["mid", "ready", "finished", "advanced"] {
            let data = try Data(contentsOf: URL(fileURLWithPath: exchange).appendingPathComponent("kotlin-guided-\(checkpoint).json"))
            let c = try JSONDecoder().decode(Character.self, from: data)
            let original = try JSONSerialization.jsonObject(with: data) as! NSDictionary
            let roundTrip = try JSONSerialization.jsonObject(with: encoder.encode(c)) as! NSDictionary
            #expect(original.isEqual(roundTrip))
            if checkpoint == "mid" { #expect(c.isInCreation); #expect(c.creation?.favoredAttribute == .dexterity); #expect(c.creationReport.isWithinLimits) }
            if checkpoint == "ready" { #expect(c.creationSteps.allSatisfy { $0.status == .done }); #expect(c.creation?.favoredAttribute == .presence) }
            if checkpoint == "finished" { #expect(!c.isInCreation); #expect(c.experiencesAvailable == 15); c.finishCreation(bonusExperiences: 100); #expect(c.experiences == 15) }
            if checkpoint == "advanced" { #expect(c.experiencesAvailable == 10); #expect(c.changeLog.suffix(5).allSatisfy { $0.duringCreation == nil }) }
        }
    }
}

/// The bloodline, creation and refund boundary shared with the Android engine.
@MainActor
struct BloodlineContractTests {
    private struct Step: Decodable {
        let action: String
        let text: String?
        let rating: Int?
        let available, logCount: Int
    }
    @Test func bloodlineAdvancementMatchesAndroid() throws {
        let encoder = JSONEncoder()
        let steps = try JSONDecoder().decode([Step].self, from: SaveFixtures.resource("bloodline-advancement"))
        var c = Character()
        c.xpMode = true
        let id = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
        let entry = try #require(Catalog.bundled.disciplines.entry("cachexy"))
        for (index, step) in steps.enumerated() {
            let before = c.traitSnapshot
            switch step.action {
            case "clan": c.clan = step.text!
            case "bloodline": c.bloodline = step.text!
            case "add":
                if c.reasonCantLearn(entry) == nil { c.disciplines.append(Discipline(id: id, source: .catalog(entry.id), rating: 1)) }
            case "rating": try #require(c.disciplines.first { $0.id == id }).rating = step.rating!
            case "remove": c.disciplines.removeAll { $0.id == id }
            default: Issue.record("Unsupported bloodline action")
            }
            c.recordChanges(since: before, at: Date(timeIntervalSinceReferenceDate: 800000000.25 + Double(index)))
            c = try JSONDecoder().decode(Character.self, from: encoder.encode(c))
            #expect(c.experiencesAvailable == step.available)
            #expect(c.changeLog.count == step.logCount)
        }
        if let path = SaveFixtures.exchange("bloodline-advancement.json") {
            try encoder.encode(c).write(to: URL(fileURLWithPath: path).appendingPathComponent("swift-bloodline.json"))
        }
    }
    @Test func readsKotlinBloodline() throws {
        guard ProcessInfo.processInfo.environment["REQUIEM_CHECK_KOTLIN"] == "1",
              let path = SaveFixtures.exchange("bloodline-advancement.json") else { return }
        let file = try Data(contentsOf: URL(fileURLWithPath: path).appendingPathComponent("kotlin-bloodline.json"))
        let c = try JSONDecoder().decode(Character.self, from: file)
        #expect(c.bloodlineSource == .catalog("morbus"))
        #expect(c.disciplineRating("cachexy") == 2)
        #expect(c.experiencesAvailable == -6)
        #expect(c.changeLog.map(\.experiences) == [3, 3, 4, -7, -3, 3, 3])
        #expect(try JSONSerialization.jsonObject(with: JSONEncoder().encode(c)) as? NSDictionary == JSONSerialization.jsonObject(with: file) as? NSDictionary)
    }
}

/// Exercises the public transfer API, as well as the decoder, against Android's exported files.
@MainActor
struct CharacterTransferContractTests {
    private var names: [String] { SaveFixtures.names("transfer") }

    @Test func declarationsMatchActualReaderAndConditionalWriters() throws {
        let p = SaveFixtures.contract.platforms["ios"]!
        #expect(p.readSchema == Character.currentSchemaVersion)
        let plain = Character()
        let conditions = try JSONDecoder().decode(Character.self, from: SaveFixtures.data("v11-conditions"))
        let history = try JSONDecoder().decode(Character.self, from: SaveFixtures.data("v11-conditions"))
        history.conditions.removeAll()
        let elder = Character(); elder.elderBaneActive = true
        let both = try JSONDecoder().decode(Character.self, from: SaveFixtures.data("v12-elder-bane"))
        let off = Character(); off.elderBaneActive = true; off.elderBaneActive = false
        let cases = ["plain": plain, "conditions": conditions, "history": history, "elder": elder, "elder-and-conditions": both, "elder-off": off]
        #expect(Set(cases.keys) == Set(p.writers.keys))
        for (name, c) in cases {
            let fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(c)) as? [String: Any])
            #expect(fields["schemaVersion"] as? Int == p.writers[name])
            #expect((fields["elderBaneActive"] != nil) == c.elderBaneActive)
        }
    }

    @Test func everyNewerScenarioIsRejectedWithoutChangingStorage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Reject-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CharacterStore(directory: directory)
        let original = try SaveFixtures.data("v10-advanced")
        let id = try store.importCharacter(store.prepareImport(of: original))
        let newer = SaveFixtures.contract.scenarios.filter { $0.key.hasPrefix("characters/") && ($0.value.schema ?? 1) > Character.currentSchemaVersion }
        var files = try newer.keys.sorted().map { try SaveFixtures.resource($0.replacingOccurrences(of: ".json", with: "")) }
        files.append(try JSONSerialization.data(withJSONObject: ["name": "Future save", "schemaVersion": Character.currentSchemaVersion + 1, "unknownFutureState": ["retain": true]]))
        for data in files {
            let fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let version = try #require(fields["schemaVersion"] as? Int)
            #expect(throws: CharacterStoreError.newerFormat(version: version)) { try store.prepareImport(of: data) }
            #expect(try store.exportData(for: id) == original)
            let futureID = UUID()
            let url = directory.appendingPathComponent(futureID.uuidString + ".json")
            try data.write(to: url)
            #expect(throws: CharacterStoreError.newerFormat(version: version)) { try store.load(futureID) }
            #expect(try Data(contentsOf: url) == data)
        }
    }

    @Test func sharedCopyNamesMatchAndroid() throws {
        struct CopyCase: Decodable { let name: String; let taken: [String]; let copy: String }
        let cases = try JSONDecoder().decode([CopyCase].self, from: SaveFixtures.resource("character-transfer"))
        for value in cases {
            #expect(CharacterStore.copyName(for: value.name, taken: Set(value.taken)) == value.copy)
        }
    }

    @Test func exportsActualStoredFilesForAndroid() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Transfer-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CharacterStore(directory: directory)
        for name in names {
            let bytes = try SaveFixtures.data(name)
            let pending = try store.prepareImport(of: bytes)
            let id = try store.importCharacter(pending)
            let exported = try store.exportData(for: id)
            #expect(exported == bytes)
            if let exchange = SaveFixtures.exchange("characters/\(name).json") {
                try exported.write(to: URL(fileURLWithPath: exchange).appendingPathComponent("swift-transfer-\(name).vtrcharacter"))
            }
        }
    }

    @Test func readsKotlinCharacterTransfers() throws {
        guard ProcessInfo.processInfo.environment["REQUIEM_CHECK_KOTLIN"] == "1",
              let exchange = ProcessInfo.processInfo.environment["REQUIEM_EXCHANGE_DIR"] else { return }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Transfer-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CharacterStore(directory: directory)
        for name in names {
            guard SaveFixtures.selected("characters/\(name).json") else { continue }
            let bytes = try Data(contentsOf: URL(fileURLWithPath: exchange).appendingPathComponent("kotlin-transfer-\(name).vtrcharacter"))
            let pending = try store.prepareImport(of: bytes)
            let id = try store.importCharacter(pending)
            #expect(try store.exportData(for: id) == bytes)
            let copiedBytes = try Data(contentsOf: URL(fileURLWithPath: exchange).appendingPathComponent("kotlin-transfer-copy-\(name).vtrcharacter"))
            let copied = try store.prepareImport(of: copiedBytes)
            #expect(copied.existing == nil)
            #expect(copied.character.id != id)
            #expect(copied.character.name == CharacterStore.copyName(for: pending.character.name, taken: []))
            let copyID = try store.importCharacter(copied)
            #expect(try store.exportData(for: copyID) == copiedBytes)
            var original = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            var copy = try #require(JSONSerialization.jsonObject(with: copiedBytes) as? [String: Any])
            for key in ["id", "name"] { original.removeValue(forKey: key); copy.removeValue(forKey: key) }
            #expect(NSDictionary(dictionary: original) == NSDictionary(dictionary: copy))
        }
    }
}
