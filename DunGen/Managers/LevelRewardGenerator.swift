import Foundation
import FoundationModels
import OSLog

@MainActor
final class LevelRewardGenerator {
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "LevelRewardGenerator")

    enum RewardType {
        case ability
        case spell
        case prayer
    }

    struct RewardGenerationResult {
        let rewardName: String
        let rewardType: RewardType
    }

    func generateLevelReward(
        session: LanguageModelSession,
        character: CharacterProfile,
        className: String,
        level: Int
    ) async throws -> RewardGenerationResult? {
        let (rewardType, rewardList) = determineRewardType(for: className)
        let existingRewards = Set(character.abilities + character.spells)

        return try await generateUniqueReward(
            session: session,
            rewardType: rewardType,
            rewardList: rewardList,
            className: className,
            level: level,
            existingRewards: existingRewards
        )
    }

    private func determineRewardType(for className: String) -> (RewardType, String) {
        switch className.lowercased() {
        case "mage", "necromancer":
            let spellType = className.lowercased() == "necromancer" ? "death spell" : "arcane spell"
            return (.spell, spellType)
        case "healer", "paladin":
            return (.prayer, "divine prayer")
        case "druid":
            return (.spell, "nature spell")
        default:
            return (.ability, "class ability")
        }
    }

    private func generateUniqueReward(
        session: LanguageModelSession,
        rewardType: RewardType,
        rewardList: String,
        className: String,
        level: Int,
        existingRewards: Set<String>
    ) async throws -> RewardGenerationResult? {
        var attempts = 0
        let maxAttempts = 5

        while attempts < maxAttempts {
            attempts += 1

            var prompt = "Character: Level \(level) \(className). Generate a single new \(rewardList). Provide only the name of the \(rewardList)."

            if !existingRewards.isEmpty {
                let recentRewards = Array(existingRewards.prefix(5)).joined(separator: ", ")
                prompt += " Already has: \(recentRewards)."
            }

            prompt += " Generate a unique \(rewardList) appropriate for this level and class."

            if attempts > 1 {
                prompt += " AVOID duplicates."
            }

            logger.debug("[Level Reward] Attempt \(attempts), Prompt length: \(prompt.count) chars")

            var options = GenerationOptions()
            options.temperature = 0.5        // Balanced mechanics + flavor

            let response = try await session.respond(to: prompt, generating: LevelReward.self, options: options)
            let reward = response.content.name

            if !existingRewards.contains(reward) {
                logger.debug("[Level Reward] Generated unique reward: \(reward)")
                return RewardGenerationResult(rewardName: reward, rewardType: rewardType)
            } else {
                logger.debug("[Level Reward] Duplicate reward '\(reward)' detected, regenerating...")
            }
        }

        logger.warning("[Level Reward] Failed to generate unique reward after \(maxAttempts) attempts")
        return nil
    }
}
