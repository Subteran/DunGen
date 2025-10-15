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

    var id: String { name }
    var visited: Bool = false
    var completed: Bool = false
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
    @Guide(description: "Clear quest goal describing what needs to be accomplished (1 sentence)")
    var questGoal: String
    @Guide(description: "Current encounter number (1-based)")
    var currentEncounter: Int
    @Guide(description: "Total encounters planned for this adventure (7-12)", .range(7...12))
    var totalEncounters: Int
    @Guide(description: "Whether the final boss/challenge has been defeated")
    var completed: Bool

    var progress: String {
        "\(currentEncounter)/\(totalEncounters)"
    }

    var isFinalEncounter: Bool {
        currentEncounter >= totalEncounters
    }
}

@Generable(description: "One turn of the adventure including narration and updates")
struct AdventureTurn: Codable, Equatable {
    @Guide(description: "Narrative text for this turn (2-4 short paragraphs)")
    var narration: String

    @Guide(description: "Updated adventure progress")
    var adventureProgress: AdventureProgress?

    @Guide(description: "A concise prompt asking the player for the next action")
    var playerPrompt: String?

    @Guide(description: "Two distinct action options for the player to choose from (e.g., 'Attack the goblin', 'Search the room')", .count(2...2))
    var suggestedActions: [String]

    @Guide(description: "Current specific environment/location description (e.g., 'Dark forest clearing', 'Tavern common room', 'Dungeon entrance hall'). Only change if player explicitly moves to a new location.")
    var currentEnvironment: String?

    @Guide(description: "Suggested next location type if transitioning")
    var nextLocationType: AdventureType?
}
