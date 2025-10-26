import Foundation
import OSLog

@MainActor
final class QuestProgressManager {
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "QuestProgressManager")

    func buildQuestProgressionGuidance(for adventure: AdventureProgress) -> String {
        let nextEncounter = adventure.currentEncounter + 1

        if adventure.completed {
            return "\n✓ QUEST DONE: '\(adventure.questGoal)' achieved. Wrap up briefly."
        }

        var guidance = ""
        let progressPercent = Double(nextEncounter) / Double(adventure.totalEncounters)

        if progressPercent <= 0.4 {
            guidance += "\nSTAGE-EARLY: Intro clues/NPCs/hints for '\(adventure.questGoal)'. Show obstacles."
        } else if progressPercent <= 0.85 {
            guidance += "\nSTAGE-MID: Advance '\(adventure.questGoal)'. Retrieval: show item/location. Combat: show boss/lair. Make progress."
        }

        if nextEncounter >= adventure.totalEncounters {
            guidance += buildFinalEncounterGuidance(adventure: adventure, nextEncounter: nextEncounter)
        }

        return guidance
    }

    private func buildFinalEncounterGuidance(adventure: AdventureProgress, nextEncounter: Int) -> String {
        let encountersOver = nextEncounter - adventure.totalEncounters
        let questLower = adventure.questGoal.lowercased()

        let completionInstructions = determineCompletionInstructions(for: questLower)

        if encountersOver == 0 {
            return "\n⚠ FINAL ENC: \(nextEncounter)/\(adventure.totalEncounters). Quest: '\(adventure.questGoal)'. \(completionInstructions) Only completed=true if action completes goal."
        } else if encountersOver < 3 {
            return "\n⚠ FINALE+\(encountersOver): \(nextEncounter)/\(adventure.totalEncounters). Quest: '\(adventure.questGoal)'. \(completionInstructions) 3 extra max or fail."
        } else {
            return "\n⚠ LAST CHANCE: \(nextEncounter)/\(adventure.totalEncounters) (3/3 extra). FINAL chance for '\(adventure.questGoal)'. \(completionInstructions) Fail if not done now."
        }
    }

    private func determineCompletionInstructions(for questLower: String) -> String {
        if questLower.contains("find") || questLower.contains("retrieve") || questLower.contains("locate") || questLower.contains("discover") {
            return "Show artifact. completed=true when taken."
        } else if questLower.contains("defeat") || questLower.contains("kill") || questLower.contains("destroy") || questLower.contains("stop") || questLower.contains("eliminate") {
            return "Boss fight via combat. completed=true on win."
        } else if questLower.contains("escort") || questLower.contains("protect") || questLower.contains("guide") {
            return "Show destination/threat. completed=true on reach/defeat."
        } else if questLower.contains("investigate") || questLower.contains("solve") || questLower.contains("uncover") {
            return "Show solution. completed=true on acknowledgment."
        } else if questLower.contains("rescue") || questLower.contains("save") || questLower.contains("free") {
            return "Show captive. completed=true on free (win/unlock)."
        } else if questLower.contains("negotiate") || questLower.contains("persuade") || questLower.contains("convince") || questLower.contains("diplomacy") {
            return "Show NPC. completed=true on agreement."
        } else {
            return "Show objective. completed=true on achievement."
        }
    }

    func checkQuestFailure(adventure: AdventureProgress) -> Bool {
        guard adventure.isFinalEncounter else { return false }
        let encountersOverLimit = adventure.currentEncounter - adventure.totalEncounters
        return encountersOverLimit >= 3 && !adventure.completed
    }

    func createFailedQuestSummary(
        adventure: AdventureProgress,
        currentAdventureXP: Int,
        currentAdventureGold: Int,
        currentAdventureMonsters: Int,
        recentItems: [String]
    ) -> AdventureSummary {
        return AdventureSummary(
            locationName: adventure.locationName,
            questGoal: adventure.questGoal,
            completionSummary: "Quest failed - objective not completed in time",
            encountersCompleted: adventure.currentEncounter,
            totalXPGained: currentAdventureXP,
            totalGoldEarned: currentAdventureGold,
            notableItems: recentItems,
            monstersDefeated: currentAdventureMonsters
        )
    }
}
