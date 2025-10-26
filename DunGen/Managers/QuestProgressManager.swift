import Foundation
import OSLog

@MainActor
final class QuestProgressManager {
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "QuestProgressManager")

    func buildQuestProgressionGuidance(for adventure: AdventureProgress) -> String {
        let nextEncounter = adventure.currentEncounter + 1

        if adventure.completed {
            return "\nQUEST COMPLETED: The quest '\(adventure.questGoal)' has been achieved. Wrap up the scene briefly - the adventure is complete."
        }

        var guidance = ""
        let progressPercent = Double(nextEncounter) / Double(adventure.totalEncounters)

        if progressPercent <= 0.4 {
            guidance += "\nQUEST STAGE - EARLY: Introduce clues, NPCs, or hints related to '\(adventure.questGoal)'. Establish what stands between the player and their goal."
        } else if progressPercent <= 0.85 {
            guidance += "\nQUEST STAGE - MIDDLE: Directly advance toward '\(adventure.questGoal)'. If the quest is 'retrieve X', mention seeing/finding X or its location. If 'defeat Y', introduce Y or their lair. Make tangible progress."
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
            return "\nCRITICAL - FINAL ENCOUNTER: This is encounter \(nextEncounter)/\(adventure.totalEncounters) - the planned final encounter. Quest: '\(adventure.questGoal)'. \(completionInstructions) DO NOT set completed=true unless the player's action actually completes the objective."
        } else if encountersOver < 3 {
            return "\nCRITICAL - EXTENDED FINALE: This is encounter \(nextEncounter)/\(adventure.totalEncounters) (extra turn \(encountersOver)/3). Quest: '\(adventure.questGoal)'. \(completionInstructions) After 3 extra encounters, the quest will fail."
        } else {
            return "\nCRITICAL - FINAL CHANCE: This is encounter \(nextEncounter)/\(adventure.totalEncounters) (final extra turn 3/3). This is the LAST opportunity to complete '\(adventure.questGoal)'. \(completionInstructions) If not completed this turn, the quest fails."
        }
    }

    private func determineCompletionInstructions(for questLower: String) -> String {
        if questLower.contains("find") || questLower.contains("retrieve") || questLower.contains("locate") || questLower.contains("discover") {
            return "Present the artifact/item. Mark completed=true when player takes/claims it."
        } else if questLower.contains("defeat") || questLower.contains("kill") || questLower.contains("destroy") || questLower.contains("stop") || questLower.contains("eliminate") {
            return "Boss fight handled by combat system. Mark completed=true when combat is won."
        } else if questLower.contains("escort") || questLower.contains("protect") || questLower.contains("guide") {
            return "Present the destination or final threat. Mark completed=true when destination reached or threat defeated."
        } else if questLower.contains("investigate") || questLower.contains("solve") || questLower.contains("uncover") {
            return "Reveal the solution/truth. Mark completed=true when player acknowledges/understands the answer."
        } else if questLower.contains("rescue") || questLower.contains("save") || questLower.contains("free") {
            return "Present captive/prisoner. Mark completed=true when freed (combat win or unlock action)."
        } else if questLower.contains("negotiate") || questLower.contains("persuade") || questLower.contains("convince") || questLower.contains("diplomacy") {
            return "Present key NPC for negotiation. Mark completed=true when agreement reached."
        } else {
            return "Present quest objective. Mark completed=true when player's action achieves the goal."
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
