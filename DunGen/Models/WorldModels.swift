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
    var locationName: String = ""
    var adventureStory: String = ""
    var questGoal: String = ""
    var currentEncounter: Int = 1
    var totalEncounters: Int = 6

    @Guide(description: "Whether the quest objective has been achieved. Only set to true when: boss is defeated (combat quest), artifact is taken (retrieval quest), or objective is met (other quest types)")
    var completed: Bool = false

    var encounterSummaries: [String] = []
    var recentNarratives: [String] = []
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
    @Guide(description: "Adventure progress. Only update 'completed' field when quest objective achieved. Do NOT modify location, quest goal, or encounter counts.")
    var adventureProgress: AdventureProgress?

    @Guide(description: "Optional player prompt (usually omit)")
    var playerPrompt: String?

    @Guide(description: "Two action choices for player derived from the description text", .count(2...2))
    var suggestedActions: [String]

    @Guide(description: "Current area within location, update as they progress.")
    var currentEnvironment: String?

    @Guide(description: "Items player received/purchased this turn. Only set if items actually acquired. For retrieval quests: include artifact when player takes it.")
    var itemsAcquired: [String]?

    @Guide(description: "Gold spent on purchases this turn. Only set if player bought something from NPC.")
    var goldSpent: Int?

    @Guide(description: "Your scenario narrative. MUST be 3 or 4 short sentences. Second person present tense. For combat: describe ONLY monster appearing, never fighting/outcomes.")
    var narration: String
}

// Summary of a completed adventure
// NOTE: This is constructed manually by code, not generated by LLM
struct AdventureSummary: Codable, Equatable, Identifiable {
    var locationName: String
    var questGoal: String
    var completionSummary: String
    var encountersCompleted: Int
    var totalXPGained: Int
    var totalGoldEarned: Int
    var notableItems: [String]
    var monstersDefeated: Int

    var id: String { locationName }
}
