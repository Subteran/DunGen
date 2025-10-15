import Foundation
import FoundationModels

@Generable(description: "Encounter classification and setup")
struct EncounterDetails: Codable {
    @Guide(description: "Type of encounter: combat, social, exploration, puzzle, trap, stealth, or chase")
    var encounterType: String
    @Guide(description: "Encounter difficulty: easy, normal, hard, boss")
    var difficulty: String
}

@Generable(description: "Progression rewards from an encounter")
struct ProgressionRewards: Codable {
    @Guide(description: "XP reward for this encounter", .range(0...500))
    var xpGain: Int
    @Guide(description: "HP change (positive for healing, negative for damage)", .range(-50...50))
    var hpDelta: Int
    @Guide(description: "Gold reward", .range(0...1000))
    var goldGain: Int
    @Guide(description: "Should this encounter drop loot items?")
    var shouldDropLoot: Bool
    @Guide(description: "Number of items to drop (0-3)", .range(0...3))
    var itemDropCount: Int
}
