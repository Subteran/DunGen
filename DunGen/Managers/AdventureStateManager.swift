import Foundation

@MainActor
@Observable
final class AdventureStateManager {
    var adventureProgress: AdventureProgress?

    var currentAdventureXP: Int = 0
    var currentAdventureGold: Int = 0
    var currentAdventureMonsters: Int = 0

    var adventureSummary: AdventureSummary?
    var showingAdventureSummary: Bool = false

    var currentLocation: AdventureType = .outdoor
    var currentEnvironment: String = ""
    var currentWorldLocationName: String?

    var narrativeState: NarrativeState = NarrativeState()

    func reset() {
        adventureProgress = nil
        currentAdventureXP = 0
        currentAdventureGold = 0
        currentAdventureMonsters = 0
        adventureSummary = nil
        showingAdventureSummary = false
        currentEnvironment = ""
        currentWorldLocationName = nil
        narrativeState = NarrativeState()
    }

    func resetAdventureStats() {
        currentAdventureXP = 0
        currentAdventureGold = 0
        currentAdventureMonsters = 0
    }
}
