import Foundation

@MainActor
final class EncounterStateManager {
    // Internal for persistence - exposed to LLMGameEngine
    internal var encounterCounts: [String: Int] = [:]
    internal var lastEncounter: String?
    internal var encountersSinceLastTrap: Int = 0

    private var encounterKeywords: [String] = []
    private let maxKeywordHistory = 10

    struct PendingTrap: Codable, Equatable {
        let damage: Int
        let narrative: String
    }
    var pendingTrap: PendingTrap?

    func reset() {
        encounterCounts = [:]
        lastEncounter = nil
        encountersSinceLastTrap = 0
        encounterKeywords = []
        pendingTrap = nil
    }

    func trackEncounter(_ type: String) {
        encounterCounts[type, default: 0] += 1
        lastEncounter = type

        if type != "trap" {
            encountersSinceLastTrap += 1
        } else {
            encountersSinceLastTrap = 0
        }
    }

    func lastEncounterType() -> String? {
        lastEncounter
    }

    func countSinceLastTrap() -> Int {
        encountersSinceLastTrap
    }

    func storeKeywords(_ keywords: String) {
        if !keywords.isEmpty {
            encounterKeywords.append(keywords)
            if encounterKeywords.count > maxKeywordHistory {
                encounterKeywords.removeFirst()
            }
        }
    }

    func extractRecentKeywords() -> String {
        encounterKeywords.suffix(3).joined(separator: ", ")
    }
}
