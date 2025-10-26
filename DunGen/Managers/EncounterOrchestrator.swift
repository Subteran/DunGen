import Foundation
import FoundationModels
import OSLog

@MainActor
final class EncounterOrchestrator {
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "EncounterOrchestrator")

    weak var gameEngine: LLMGameEngine?

    func shouldContinueNPCConversation(activeNPC: NPCDefinition?, activeNPCTurns: Int, playerAction: String?) -> Bool {
        guard let npc = activeNPC else { return false }
        guard activeNPCTurns < 2 else { return false }

        let playerActionLower = (playerAction ?? "").lowercased()
        let isReferencingNPC = playerActionLower.contains(npc.name.lowercased()) ||
            (playerActionLower.contains("speak to") ||
             playerActionLower.contains("talk to") ||
             playerActionLower.contains("ask the") ||
             playerActionLower.contains("tell the"))

        return isReferencingNPC
    }

    func generateEncounter(
        session: LanguageModelSession,
        adventure: AdventureProgress?,
        character: CharacterProfile?,
        characterLevel: Int,
        location: String,
        encounterCounts: [String: Int],
        enforceVariety: (inout EncounterDetails) -> Void
    ) async throws -> EncounterDetails {
        let encounterContext = ContextBuilder.buildContext(
            for: .encounter,
            character: character,
            characterLevel: characterLevel,
            adventure: adventure,
            location: location,
            encounterCounts: encounterCounts
        )

        var encounterPrompt = encounterContext
        if let adventure = adventure {
            if adventure.isFinalEncounter {
                encounterPrompt += buildFinalEncounterPrompt(for: adventure)
            }
        }
        encounterPrompt += " Determine encounter type and difficulty. For trap encounters, scale danger with player level."

        logger.debug("[Encounter LLM] Prompt length: \(encounterPrompt.count) chars")
        let encounterResponse = try await session.respond(to: encounterPrompt, generating: EncounterDetails.self)
        var encounter = encounterResponse.content

        enforceFinalEncounterType(for: adventure, encounter: &encounter)
        enforceVariety(&encounter)

        logger.debug("[Encounter LLM] Success")
        return encounter
    }

    private func buildFinalEncounterPrompt(for adventure: AdventureProgress) -> String {
        let questLower = adventure.questGoal.lowercased()

        if questLower.contains("find") || questLower.contains("retrieve") || questLower.contains("locate") || questLower.contains("discover") {
            return " This is the FINAL encounter - use 'final' type (non-combat) to present the artifact/objective for retrieval."
        } else if questLower.contains("defeat") || questLower.contains("kill") || questLower.contains("destroy") || questLower.contains("stop") || questLower.contains("eliminate") {
            return " This is the FINAL encounter - use 'combat' type with 'boss' difficulty to present the enemy."
        } else if questLower.contains("escort") || questLower.contains("protect") || questLower.contains("guide") {
            return " This is the FINAL encounter - use 'final' type to reach the destination, or 'combat' with 'hard' difficulty if there's a final threat to overcome."
        } else if questLower.contains("investigate") || questLower.contains("solve") || questLower.contains("uncover") {
            return " This is the FINAL encounter - use 'final' type to reveal the solution/truth of the mystery."
        } else if questLower.contains("rescue") || questLower.contains("save") || questLower.contains("free") {
            return " This is the FINAL encounter - use 'combat' type with 'hard' difficulty if rescuing from captor, or 'final' type if freeing from trap/prison."
        } else if questLower.contains("negotiate") || questLower.contains("persuade") || questLower.contains("convince") || questLower.contains("diplomacy") {
            return " This is the FINAL encounter - use 'social' type for the critical negotiation/persuasion."
        } else {
            return " This is the FINAL encounter - use 'final' type to resolve the quest goal."
        }
    }

    private func enforceFinalEncounterType(for adventure: AdventureProgress?, encounter: inout EncounterDetails) {
        guard let adventure = adventure else { return }

        let nextEncounter = adventure.currentEncounter + 1
        let willBeFinalEncounter = nextEncounter >= adventure.totalEncounters

        guard willBeFinalEncounter else { return }

        let questLower = adventure.questGoal.lowercased()
        if questLower.contains("defeat") || questLower.contains("kill") || questLower.contains("destroy") || questLower.contains("stop") || questLower.contains("eliminate") {
            encounter.encounterType = "combat"
            encounter.difficulty = "boss"
            logger.info("[Encounter] ENFORCED boss combat for combat quest final encounter (will be \(nextEncounter)/\(adventure.totalEncounters))")
        } else if questLower.contains("find") || questLower.contains("retrieve") || questLower.contains("locate") || questLower.contains("discover") {
            encounter.encounterType = "final"
            logger.info("[Encounter] ENFORCED final (non-combat) for retrieval quest final encounter (will be \(nextEncounter)/\(adventure.totalEncounters))")
        }
    }
}
