import Foundation
import FoundationModels

@Generable(description: "A non-player character")
struct NPCDefinition: Codable, Equatable, Identifiable {
    @Guide(description: "Unique NPC name")
    var name: String
    @Guide(description: "NPC occupation or role (merchant, guard, innkeeper, priest, blacksmith, etc.)")
    var occupation: String
    @Guide(description: "Physical appearance (1-2 sentences)")
    var appearance: String
    @Guide(description: "Personality traits (1-2 sentences)")
    var personality: String
    @Guide(description: "Current location in the world")
    var location: String
    @Guide(description: "Brief backstory or context (1-2 sentences)")
    var backstory: String
    @Guide(description: "Current relationship status with player: neutral, friendly, hostile, allied")
    var relationshipStatus: String
    @Guide(description: "Number of previous interactions with player", .range(0...100))
    var interactionCount: Int

    var id: String { name }
}

@Generable(description: "NPC dialogue response")
struct NPCDialogue: Codable {
    @Guide(description: "The NPC speaking")
    var npcName: String
    @Guide(description: "Dialogue spoken by NPC (2-4 sentences in character)")
    var dialogue: String
    @Guide(description: "NPC's current mood: happy, sad, angry, fearful, neutral, excited, suspicious")
    var mood: String
    @Guide(description: "Optional quest or task the NPC might offer")
    var questHook: String?
}
