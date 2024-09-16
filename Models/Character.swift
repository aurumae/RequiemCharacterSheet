//
//  Character.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

import Foundation
import Combine

class Character: ObservableObject, Codable {
    @Published var attributes: [Attribute]
    @Published var healthDamage: Int = 0
    @Published var healthBoxes: [HealthBox]
    @Published var willpowerSpent: Int = 0
    @Published var willpowerBoxes: [WillpowerBox]
    @Published var skills: [Skill]
    
    // New character detail properties
    @Published var name: String
    @Published var player: String
    @Published var chronicle: String
    @Published var mask: String
    @Published var dirge: String
    @Published var concept: String
    @Published var clan: String
    @Published var bloodline: String
    @Published var covenant: String
    
    @Published var bloodPotency: Int
    @Published var maxVitae: Int
    @Published var vitaePerTurn: Int
    @Published var currentVitae: Int
    
    @Published var humanity: Int
    @Published var touchstones: [Touchstone]
    
    @Published var disciplines: [Discipline]
    @Published var merits: [Merit]
    
    @Published var aspirations: [Aspiration]
    @Published var banes: [Bane]
    
    @Published var size: Int
    @Published var armor: Int
    
    @Published var beats: Int
    @Published var experiences: Int
    
    private var cancellables = Set<AnyCancellable>()
    
    enum CodingKeys: CodingKey {
        case attributes, bloodPotency, healthDamage, willpowerSpent, healthBoxes, willpowerBoxes, skills,
             name, player, chronicle, mask, dirge, concept, clan, bloodline, covenant,
             maxVitae, vitaePerTurn, currentVitae, humanity, touchstones, disciplines, merits,
             aspirations, banes, size, armor, beats, experiences
    }
    
    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(attributes, forKey: .attributes)
        try container.encode(healthDamage, forKey: .healthDamage)
        try container.encode(willpowerSpent, forKey: .willpowerSpent)
        try container.encode(healthBoxes, forKey: .healthBoxes)
        try container.encode(willpowerBoxes, forKey: .willpowerBoxes)
        try container.encode(skills, forKey: .skills)
        
        try container.encode(name, forKey: .name)
        try container.encode(player, forKey: .player)
        try container.encode(chronicle, forKey: .chronicle)
        try container.encode(mask, forKey: .mask)
        try container.encode(dirge, forKey: .dirge)
        try container.encode(concept, forKey: .concept)
        try container.encode(clan, forKey: .clan)
        try container.encode(bloodline, forKey: .bloodline)
        try container.encode(covenant, forKey: .covenant)
        
        try container.encode(bloodPotency, forKey: .bloodPotency)
        try container.encode(maxVitae, forKey: .maxVitae)
        try container.encode(vitaePerTurn, forKey: .vitaePerTurn)
        try container.encode(currentVitae, forKey: .currentVitae)
        
        try container.encode(humanity, forKey: .humanity)
        try container.encode(touchstones, forKey: .touchstones)
        
        try container.encode(disciplines, forKey: .disciplines)
        try container.encode(merits, forKey: .merits)
        
        try container.encode(aspirations, forKey: .aspirations)
        try container.encode(banes, forKey: .banes)
        
        try container.encode(size, forKey: .size)
        try container.encode(armor, forKey: .armor)
        
        try container.encode(beats, forKey: .beats)
        try container.encode(experiences, forKey: .experiences)
    }
    
    // Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attributes = try container.decode([Attribute].self, forKey: .attributes)
        healthDamage = try container.decode(Int.self, forKey: .healthDamage)
        willpowerSpent = try container.decode(Int.self, forKey: .willpowerSpent)
        healthBoxes = try container.decode([HealthBox].self, forKey: .healthBoxes)
        willpowerBoxes = try container.decode([WillpowerBox].self, forKey: .willpowerBoxes)
        skills = try container.decode([Skill].self, forKey: .skills)
        
        name = try container.decode(String.self, forKey: .name)
        player = try container.decode(String.self, forKey: .player)
        chronicle = try container.decode(String.self, forKey: .chronicle)
        mask = try container.decode(String.self, forKey: .mask)
        dirge = try container.decode(String.self, forKey: .dirge)
        concept = try container.decode(String.self, forKey: .concept)
        clan = try container.decode(String.self, forKey: .clan)
        bloodline = try container.decode(String.self, forKey: .bloodline)
        covenant = try container.decode(String.self, forKey: .covenant)
        
        bloodPotency = try container.decode(Int.self, forKey: .bloodPotency)
        maxVitae = try container.decode(Int.self, forKey: .maxVitae)
        vitaePerTurn = try container.decode(Int.self, forKey: .vitaePerTurn)
        currentVitae = try container.decode(Int.self, forKey: .currentVitae)
        
        humanity = try container.decode(Int.self, forKey: .humanity)
        touchstones = try container.decode([Touchstone].self, forKey: .touchstones)
        
        disciplines = try container.decode([Discipline].self, forKey: .disciplines)
        merits = try container.decode([Merit].self, forKey: .merits)
        
        aspirations = try container.decode([Aspiration].self, forKey: .aspirations)
        banes = try container.decode([Bane].self, forKey: .banes)
        
        size = try container.decode(Int.self, forKey: .size)
        armor = try container.decode(Int.self, forKey: .armor)
        
        beats = try container.decode(Int.self, forKey: .beats)
        experiences = try container.decode(Int.self, forKey: .experiences)
        
        self.cancellables = Set<AnyCancellable>()
        // Re-establish observers
        setupAttributeObservers() // Keep this one at the top
        setupSkillObservers()
        setupBloodPotencyObserver()
        setupDisciplineObservers()
    }
    
    init() {
        // Initialize attributes as a local variable
        let attributes = [
            Attribute(name: "Intelligence", rating: 1),
            Attribute(name: "Wits", rating: 1),
            Attribute(name: "Resolve", rating: 1),
            Attribute(name: "Strength", rating: 1),
            Attribute(name: "Dexterity", rating: 1),
            Attribute(name: "Stamina", rating: 1),
            Attribute(name: "Presence", rating: 1),
            Attribute(name: "Manipulation", rating: 1),
            Attribute(name: "Composure", rating: 1)
        ]
        
        // Compute stamina using the local attributes variable
        let stamina = attributes.first { $0.name == "Stamina" }?.rating ?? 0
        
        let size = 5 // Assuming size is constant for now
        //let armor = 0
        
        let totalHealth = stamina + size
        //let healthBoxes = Array(repeating: HealthBox(), count: totalHealth)
        let healthBoxes = (0..<totalHealth).map { _ in HealthBox() }
        
        // Compute resolve and composure using the local attributes variable
        let resolve = attributes.first { $0.name == "Resolve" }?.rating ?? 0
        let composure = attributes.first { $0.name == "Composure" }?.rating ?? 0
        let willpower = resolve + composure
        let willpowerBoxes = (0..<willpower).map { _ in WillpowerBox() }
        
        // Now assign to self after all computations
        self.attributes = attributes
        
        self.bloodPotency = 1
        self.maxVitae = 0
        self.vitaePerTurn = 1
        self.currentVitae = 0
        
        self.healthBoxes = healthBoxes
        self.healthDamage = 0
        self.willpowerSpent = 0
        self.willpowerBoxes = willpowerBoxes
        
        self.humanity = 7
        self.touchstones = (1...10).map { Touchstone(level: $0) }
        
        self.disciplines = [Discipline()] // Start with one empty Discipline
        self.merits = [Merit()] // Start with one empty Merit
        
        self.aspirations = [Aspiration()] // Start with one empty Aspiration
        self.banes = [Bane()] // Start with one empty Bane
        
        self.size = 5
        self.armor = 0
        
        self.beats = 0
        self.experiences = 0
        
        self.cancellables = Set<AnyCancellable>()
        
        // Initialize skills
        let mentalSkills = [
            "Academics", "Computer", "Crafts", "Investigation", "Medicine", "Occult", "Politics", "Science"
        ]
        let physicalSkills = [
            "Athletics", "Brawl", "Drive", "Firearms", "Larceny", "Stealth", "Survival", "Weaponry"
        ]
        let socialSkills = [
            "Animal Ken", "Empathy", "Expression", "Intimidation", "Persuasion", "Socialize", "Streetwise", "Subterfuge"
        ]
        
        let allSkills = (mentalSkills + physicalSkills + socialSkills).map { Skill(name: $0) }
        self.skills = allSkills
        
        // Initialize character detail properties
        self.name = ""
        self.player = ""
        self.chronicle = ""
        self.mask = ""
        self.dirge = ""
        self.concept = ""
        self.clan = ""
        self.bloodline = ""
        self.covenant = ""
        
        // Now you can safely use self
        // Initialize Vitae based on initial Blood Potency
        updateVitaeData()
        
        // Re-establish observers
        setupAttributeObservers() // Keep this one at the top
        setupSkillObservers()
        setupBloodPotencyObserver()
        setupDisciplineObservers()
        
    }
    
    // Derived attributes
    var health: Int {
        //let stamina = attributes.first { $0.name == "Stamina" }?.rating ?? 0
        // Assuming size is constant for now
        return adjustedStamina + size
    }
    
    var willpower: Int {
        let resolve = attributes.first { $0.name == "Resolve" }?.rating ?? 0
        let composure = attributes.first { $0.name == "Composure" }?.rating ?? 0
        return resolve + composure
    }
    
    // Computed properties for derived attributes
    var adjustedStamina: Int {
        let baseStamina = attributes.first { $0.name == "Stamina" }?.rating ?? 0
        let resilienceRating = disciplines.first { $0.name.lowercased() == "resilience" }?.rating ?? 0
        return baseStamina + resilienceRating
    }
    
    var defense: Int {
        let dexterity = attributes.first { $0.name == "Dexterity" }?.rating ?? 0
        let wits = attributes.first { $0.name == "Wits" }?.rating ?? 0
        let athletics = skills.first { $0.name == "Athletics" }?.rating ?? 0
        let celerityRating = disciplines.first { $0.name.lowercased() == "celerity" }?.rating ?? 0
        let lowerAttribute = min(dexterity, wits)
        return lowerAttribute + athletics + celerityRating
    }
    
    var speed: Int {
        let strength = attributes.first { $0.name == "Strength" }?.rating ?? 0
        let dexterity = attributes.first { $0.name == "Dexterity" }?.rating ?? 0
        let vigorRating = disciplines.first { $0.name.lowercased() == "vigor" }?.rating ?? 0
        return 5 + strength + dexterity + vigorRating
    }
    
    var initiativeMod: Int {
        let dexterity = attributes.first { $0.name == "Dexterity" }?.rating ?? 0
        let composure = attributes.first { $0.name == "Composure" }?.rating ?? 0
        return dexterity + composure
    }
    
    private func setupAttributeObservers() {
        // Clear previous subscriptions if any
        cancellables.removeAll()
        
        // Observe each attribute's objectWillChange publisher
        for attribute in attributes {
            attribute.objectWillChange
                .receive(on: DispatchQueue.main) // Ensure we're on the main thread
                .sink { [weak self] _ in
                    self?.updateHealthBoxes()
                    self?.updateWillpowerBoxes()
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
    }
    
    private func setupSkillObservers() {
        // Clear previous subscriptions related to skills
        // If you have a separate Set<AnyCancellable> for skills, clear it here
        for skill in skills {
            skill.objectWillChange
                .receive(on: DispatchQueue.main) // Ensure updates happen on the main thread
                .sink { [weak self] _ in
                    // Actions to perform when a skill changes
                    self?.updateHealthBoxes()
                    self?.updateWillpowerBoxes()
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
    }
    
    private func setupBloodPotencyObserver() {
        $bloodPotency
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateVitaeData()
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // Add this method
    private func setupDisciplineObservers() {
        // Observe changes to the disciplines array
        $disciplines
            .receive(on: DispatchQueue.main)
            .sink { [weak self] disciplines in
                self?.observeDisciplines(disciplines)
            }
            .store(in: &cancellables)
    }
    
    private func observeDisciplines(_ disciplines: [Discipline]) {
        // Cancel existing subscriptions to avoid duplicates
        // cancellables.forEach { $0.cancel() }
        // cancellables.removeAll()
        
        for discipline in disciplines {
            // Observe changes to each discipline's name and rating
            discipline.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    self?.updateDerivedAttributes()
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
    }
    
    private func updateDerivedAttributes() {
        // This method will be called when a discipline changes
        // Trigger necessary updates
        updateHealthBoxes()
        updateWillpowerBoxes()
        // If you have other updates, call them here
        objectWillChange.send()
    }
    
    private func updateHealthBoxes() {
        let totalHealth = self.health
        // Preserve existing damage types up to the new totalHealth
        let existingDamageTypes = healthBoxes.map { $0.damageType }
        let newHealthBoxes = (0..<totalHealth).map { index -> HealthBox in
            let damageType = index < existingDamageTypes.count ? existingDamageTypes[index] : .none
            return HealthBox(damageType: damageType)
        }
        self.healthBoxes = newHealthBoxes
    }
    
    private func updateWillpowerBoxes() {
        let totalWillpower = self.willpower
        // Preserve existing states up to the new totalWillpower
        let existingStates = willpowerBoxes.map { $0.state }
        let newWillpowerBoxes = (0..<totalWillpower).map { index -> WillpowerBox in
            let state = index < existingStates.count ? existingStates[index] : .none
            return WillpowerBox(state: state)
        }
        self.willpowerBoxes = newWillpowerBoxes
    }
    
    private func updateVitaeData() {
        // Mapping based on the table provided
        let (newMaxVitae, newVitaePerTurn) = getVitaeData(for: bloodPotency)
        maxVitae = newMaxVitae
        vitaePerTurn = newVitaePerTurn
        
        // Adjust currentVitae if necessary
        if currentVitae > maxVitae {
            currentVitae = maxVitae
        }
    }
    
    private func getVitaeData(for bloodPotency: Int) -> (Int, Int) {
        switch bloodPotency {
        case 0:
            let stamina = attributes.first { $0.name == "Stamina" }?.rating ?? 0
            return (stamina, 1)
        case 1:
            return (10, 1)
        case 2:
            return (11, 2)
        case 3:
            return (12, 3)
        case 4:
            return (13, 4)
        case 5:
            return (15, 5)
        case 6:
            return (20, 6)
        case 7:
            return (25, 7)
        case 8:
            return (30, 8)
        case 9:
            return (50, 10)
        case 10:
            return (75, 15)
        default:
            if bloodPotency < 0 {
                let stamina = attributes.first { $0.name == "Stamina" }?.rating ?? 0
                return (stamina, 1)
            } else {
                return (75, 15)
            }
        }
    }
    
    // Methods to handle Beats and Experiences
    func incrementBeats() {
        beats += 1
        if beats >= 5 { // If beats reaches 5, set beats to 0 and increase exp by 1
            beats = 0
            experiences += 1
        }
    }
    
    func decrementBeats() {
        if beats > 0 {
            beats -= 1
        }
    }
    
    func incrementExperiences() {
        experiences += 1
    }
    
    func decrementExperiences() {
        if experiences > 0 {
            experiences -= 1
        }
    }
}

extension Character {
    func sufferDamage(_ damageType: HealthBoxFillType) {
        switch damageType {
        case .bashing:
            applyBashingDamage()
        case .lethal:
            applyLethalDamage()
        case .aggravated:
            applyAggravatedDamage()
        case .none:
            break
        }
    }
    
    private func applyBashingDamage() {
        if let index = healthBoxes.firstIndex(where: { $0.damageType == .none }) {
            healthBoxes[index].damageType = .bashing
        } else {
            // Handle overflow or upgrades
        }
    }
    
    private func applyLethalDamage() {
        if let index = healthBoxes.firstIndex(where: { $0.damageType == .none }) {
            healthBoxes[index].damageType = .lethal
        } else {
            // Handle overflow or upgrades
        }
    }
    
    private func applyAggravatedDamage() {
        if let index = healthBoxes.firstIndex(where: { $0.damageType == .none }) {
            healthBoxes[index].damageType = .aggravated
        } else {
            // Handle overflow or upgrades
        }
    }
    
    // Similarly update applyLethalDamage() and applyAggravatedDamage()
}

// Extension for saving and loading
extension Character {
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "SavedCharacter")
            print("Character saved.")
        } else {
            print("Failed to encode character.")
        }
    }
    
    static func load() -> Character {
        if let savedData = UserDefaults.standard.data(forKey: "SavedCharacter") {
            if let decodedCharacter = try? JSONDecoder().decode(Character.self, from: savedData) {
                print("Character loaded.")
                return decodedCharacter
            } else {
                print("Failed to decode character.")
            }
        } else {
            print("No saved character found.")
        }
        return Character()
    }
}
