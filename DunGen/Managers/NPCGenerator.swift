import Foundation
import FoundationModels
import OSLog

@MainActor
final class NPCGenerator {
    private let npcRegistry: NPCRegistry
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "NPCGenerator")

    init(npcRegistry: NPCRegistry) {
        self.npcRegistry = npcRegistry
    }

    func generateOrRetrieveNPC(
        session: LanguageModelSession,
        location: String,
        encounter: EncounterDetails
    ) async throws -> NPCDefinition? {
        let existingNPCs = npcRegistry.getNPCs(atLocation: location)

        if !existingNPCs.isEmpty && Bool.random() {
            guard var npc = existingNPCs.randomElement() else { return nil }
            npc.interactionCount += 1
            npcRegistry.registerNPC(npc, location: location)
            return npc
        }

        return try await generateUniqueNPC(session: session, location: location, encounter: encounter, existingNPCs: existingNPCs)
    }

    private func generateUniqueNPC(
        session: LanguageModelSession,
        location: String,
        encounter: EncounterDetails,
        existingNPCs: [NPCDefinition]
    ) async throws -> NPCDefinition? {
        let existingNPCNames = Set(existingNPCs.map { $0.name })
        var attempts = 0
        let maxAttempts = 5

        while attempts < maxAttempts {
            attempts += 1

            var prompt = "Location: \(location). Difficulty: \(encounter.difficulty)."

            if attempts > 1 {
                prompt += " NOT: \(existingNPCNames.joined(separator: ", "))."
            }

            logger.debug("[NPC LLM] Attempt \(attempts), Prompt length: \(prompt.count) chars")

            var options = GenerationOptions()
            options.temperature = 0.5        // Consistent but varied

            let response = try await session.respond(to: prompt, generating: NPCDefinition.self, options: options)
            let candidate = response.content

            if !existingNPCNames.contains(candidate.name) {
                logger.debug("[NPC LLM] Generated unique NPC: \(candidate.name)")
                var npc = candidate
                npc.location = location
                npc.interactionCount = 0
                npcRegistry.registerNPC(npc, location: location)
                return npc
            } else {
                logger.debug("[NPC LLM] Duplicate NPC name '\(candidate.name)' detected, regenerating...")
            }
        }

        logger.warning("[NPC LLM] Failed to generate unique NPC after \(maxAttempts) attempts, using last generated")
        var options = GenerationOptions()
        options.temperature = 0.5
        var npc = try await session.respond(to: "Location: \(location). Create a new NPC.", generating: NPCDefinition.self, options: options).content
        npc.location = location
        npc.interactionCount = 0
        npcRegistry.registerNPC(npc, location: location)
        return npc
    }
}
