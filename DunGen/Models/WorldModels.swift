import Foundation
import FoundationModels

@Generable(description: "Adventure location type")
enum AdventureType: String, Codable, CaseIterable, Identifiable, Equatable {
    case outdoor = "Outdoor"
    case city = "City"
    case dungeon = "Dungeon"
    case village = "Village"

    var id: String { rawValue }
}

@Generable(description: "A location in the game world")
struct WorldLocation: Codable, Equatable {
    @Guide(description: "Name of the location")
    var name: String
    @Guide(description: "Type of location")
    var locationType: AdventureType
    @Guide(description: "Brief description of the location (1-2 sentences)")
    var description: String
    @Guide(description: "Type of quest for this location (combat, retrieval, escort, investigation, rescue, diplomatic)")
    var questType: String = "combat"
    @Guide(description: "Specific quest goal for this location (e.g., 'Defeat the bandit leader', 'Retrieve the stolen crown', 'Escort the merchant safely')")
    var questGoal: String = "Complete the quest"

    var id: String { name }
    var visited: Bool = false
    var completed: Bool = false

    // For combat quests: pre-generated boss monster
    var bossMonster: MonsterDefinition? = nil   // Complete pre-generated boss with affixes and stats

    // Custom decoding for migration support
    enum CodingKeys: String, CodingKey {
        case name, locationType, description, questType, questGoal, visited, completed
        case bossMonsterName  // Old field for migration (removed)
        case bossMonsterBaseName, bossMonsterPrefix, bossMonsterSuffix  // Old fields for migration (removed)
        case bossMonster  // Current field: complete MonsterDefinition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        locationType = try container.decode(AdventureType.self, forKey: .locationType)
        description = try container.decode(String.self, forKey: .description)
        // Migration: questType and questGoal are optional for old saves
        questType = try container.decodeIfPresent(String.self, forKey: .questType) ?? "combat"
        questGoal = try container.decodeIfPresent(String.self, forKey: .questGoal) ?? "Complete the quest"
        visited = try container.decodeIfPresent(Bool.self, forKey: .visited) ?? false
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false

        // Migration: handle old boss storage formats
        if let storedBoss = try container.decodeIfPresent(MonsterDefinition.self, forKey: .bossMonster) {
            // Current format: complete MonsterDefinition
            bossMonster = storedBoss
        } else if let baseName = try container.decodeIfPresent(String.self, forKey: .bossMonsterBaseName) {
            // Old format: separate base name + affixes (needs reconstruction)
            // Create a basic MonsterDefinition for migration
            let prefix = try container.decodeIfPresent(String.self, forKey: .bossMonsterPrefix)
            let suffix = try container.decodeIfPresent(String.self, forKey: .bossMonsterSuffix)

            bossMonster = MonsterDefinition(
                baseName: baseName,
                prefix: prefix.map { MonsterAffix(name: $0, type: "prefix", effect: "") },
                suffix: suffix.map { MonsterAffix(name: $0, type: "suffix", effect: "") },
                hp: 50,  // Placeholder stats - will be regenerated on load
                damage: "2d6",
                defense: 12,
                abilities: ["Strike"],
                description: "A powerful foe"
            )
        } else if let oldBossName = try container.decodeIfPresent(String.self, forKey: .bossMonsterName) {
            // Oldest format: just boss name
            bossMonster = MonsterDefinition(
                baseName: oldBossName,
                prefix: nil,
                suffix: nil,
                hp: 50,
                damage: "2d6",
                defense: 12,
                abilities: ["Strike"],
                description: "A powerful foe"
            )
        } else {
            bossMonster = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(locationType, forKey: .locationType)
        try container.encode(description, forKey: .description)
        try container.encode(questType, forKey: .questType)
        try container.encode(questGoal, forKey: .questGoal)
        try container.encode(visited, forKey: .visited)
        try container.encode(completed, forKey: .completed)
        try container.encodeIfPresent(bossMonster, forKey: .bossMonster)
    }

    init(name: String, locationType: AdventureType, description: String, questType: String, questGoal: String, visited: Bool = false, completed: Bool = false, bossMonster: MonsterDefinition? = nil) {
        self.name = name
        self.locationType = locationType
        self.description = description
        self.questType = questType
        self.questGoal = questGoal
        self.visited = visited
        self.completed = completed
        self.bossMonster = bossMonster
    }
}

@Generable(description: "The game world with story and locations")
struct WorldState: Codable, Equatable {
    @Guide(description: "The overarching world story (2-3 sentences)")
    var worldStory: String
    @Guide(description: "2-5 starting adventure locations including outdoor areas, villages, dungeons, and one major city", .count(2...5))
    var locations: [WorldLocation]
}

@Generable(description: "Progress through a single adventure area")
struct AdventureProgress: Codable, Equatable {
    @Guide(description: "The specific location being explored")
    var locationName: String
    @Guide(description: "Story theme for this adventure (1-2 sentences)")
    var adventureStory: String
    @Guide(description: "Specific objective for this adventure (1 sentence, e.g. 'Clear the bandits from the old mill', 'Retrieve the stolen artifact')")
    var questGoal: String
    @Guide(description: "Current encounter number (1-based)")
    var currentEncounter: Int
    @Guide(description: "Total encounters planned for this adventure (6-9)", .range(6...9))
    var totalEncounters: Int
    @Guide(description: "Whether the quest objective has been achieved (defeated boss, claimed artifact, rescued target, etc.)")
    var completed: Bool

    var encounterSummaries: [String] = []

    // Extracted quest objective (e.g., "lost heirloom", "bandit leader", "merchant")
    // Used for validation of quest completion
    var questObjective: String? = nil

    var progress: String {
        "\(currentEncounter)/\(totalEncounters)"
    }

    var isFinalEncounter: Bool {
        currentEncounter >= totalEncounters
    }
}

@Generable(description: "One turn of the adventure including narration and updates")
struct AdventureTurn: Codable, Equatable {
    @Guide(description: "Narrative text for this turn (2-4 sentences)")
    var narration: String

    @Guide(description: "Updated adventure progress")
    var adventureProgress: AdventureProgress?

    @Guide(description: "A concise prompt asking the player for the next action")
    var playerPrompt: String?

    @Guide(description: "Two distinct action options for the player to choose from (e.g., 'Attack the goblin', 'Search the room')", .count(2...2))
    var suggestedActions: [String]

    @Guide(description: "Current specific environment/location description (e.g., 'Dark forest clearing', 'Tavern common room', 'Dungeon entrance hall'). Stay within the current adventure location - do not transition to different location types.")
    var currentEnvironment: String?

    @Guide(description: "List of items purchased or received from NPCs in this encounter (e.g., ['Healing Potion', 'Iron Sword']). Empty if no items acquired.")
    var itemsAcquired: [String]?

    @Guide(description: "Amount of gold spent on purchases or services in this encounter. 0 if nothing was purchased.")
    var goldSpent: Int?
}

@Generable(description: "Summary of a completed adventure")
struct AdventureSummary: Codable, Equatable {
    @Guide(description: "Name of the location that was completed")
    var locationName: String
    @Guide(description: "The quest goal that was accomplished")
    var questGoal: String
    @Guide(description: "Brief summary of how the adventure concluded (2-3 sentences)")
    var completionSummary: String
    @Guide(description: "Number of encounters the player faced")
    var encountersCompleted: Int
    @Guide(description: "Total XP gained during the adventure")
    var totalXPGained: Int
    @Guide(description: "Total gold earned during the adventure")
    var totalGoldEarned: Int
    @Guide(description: "Notable items acquired during the adventure")
    var notableItems: [String]
    @Guide(description: "Total monsters defeated during the adventure")
    var monstersDefeated: Int
}
