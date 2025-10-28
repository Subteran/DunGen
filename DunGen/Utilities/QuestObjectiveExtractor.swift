import Foundation

struct QuestObjectiveExtractor {
    /// Extracts the specific objective from a quest goal string
    /// Examples:
    /// - "Defeat the bandit leader" -> "bandit leader"
    /// - "Retrieve the lost heirloom stolen from the city's treasury" -> "lost heirloom"
    /// - "Escort the merchant caravan safely" -> "merchant caravan"
    /// - "Rescue the kidnapped child from the bandits" -> "kidnapped child"
    /// - "Investigate the mysterious murders" -> "mysterious murders"
    /// - "Negotiate peace between rival tribes" -> "peace between rival tribes"
    static func extractObjective(from questGoal: String, questType: String) -> String? {
        let goal = questGoal.lowercased()

        switch questType.lowercased() {
        case "combat":
            return extractCombatTarget(from: goal)
        case "retrieval":
            return extractRetrievalItem(from: goal)
        case "escort":
            return extractEscortTarget(from: goal)
        case "rescue":
            return extractRescueTarget(from: goal)
        case "investigation":
            return extractInvestigationSubject(from: goal)
        case "diplomatic":
            return extractDiplomaticGoal(from: goal)
        default:
            return nil
        }
    }

    // MARK: - Quest Type Extractors

    private static func extractCombatTarget(from goal: String) -> String? {
        // "Defeat the bandit leader" -> "bandit leader"
        // "Kill the dragon guarding the cave" -> "dragon"
        let patterns = [
            "defeat the (.+?)(?:\\s+terrorizing|\\s+guarding|\\s+in|\\s+at|$)",
            "kill the (.+?)(?:\\s+terrorizing|\\s+guarding|\\s+in|\\s+at|$)",
            "destroy the (.+?)(?:\\s+terrorizing|\\s+guarding|\\s+in|\\s+at|$)",
            "stop the (.+?)(?:\\s+terrorizing|\\s+from|\\s+in|\\s+at|$)"
        ]

        return extractUsingPatterns(patterns, from: goal)
    }

    private static func extractRetrievalItem(from goal: String) -> String? {
        // "Retrieve the lost heirloom stolen from the city's treasury" -> "lost heirloom"
        // "Find the ancient artifact hidden in the ruins" -> "ancient artifact"
        let patterns = [
            "retrieve the (.+?)(?:\\s+stolen|\\s+hidden|\\s+from|\\s+in|\\s+at|$)",
            "find the (.+?)(?:\\s+stolen|\\s+hidden|\\s+from|\\s+in|\\s+at|$)",
            "locate the (.+?)(?:\\s+stolen|\\s+hidden|\\s+from|\\s+in|\\s+at|$)",
            "recover the (.+?)(?:\\s+stolen|\\s+hidden|\\s+from|\\s+in|\\s+at|$)",
            "discover the (.+?)(?:\\s+stolen|\\s+hidden|\\s+from|\\s+in|\\s+at|$)"
        ]

        return extractUsingPatterns(patterns, from: goal)
    }

    private static func extractEscortTarget(from goal: String) -> String? {
        // "Escort the merchant caravan to safety" -> "merchant caravan"
        // "Protect the princess during her journey" -> "princess"
        let patterns = [
            "escort the (.+?)(?:\\s+to|\\s+safely|\\s+through|\\s+across|$)",
            "protect the (.+?)(?:\\s+during|\\s+while|\\s+through|\\s+from|$)",
            "guide the (.+?)(?:\\s+to|\\s+safely|\\s+through|\\s+across|$)"
        ]

        return extractUsingPatterns(patterns, from: goal)
    }

    private static func extractRescueTarget(from goal: String) -> String? {
        // "Rescue the kidnapped child from the bandits" -> "kidnapped child"
        // "Save the prisoners held in the dungeon" -> "prisoners"
        let patterns = [
            "rescue the (.+?)(?:\\s+from|\\s+held|\\s+in|\\s+at|$)",
            "save the (.+?)(?:\\s+from|\\s+held|\\s+in|\\s+at|$)",
            "free the (.+?)(?:\\s+from|\\s+held|\\s+in|\\s+at|$)"
        ]

        return extractUsingPatterns(patterns, from: goal)
    }

    private static func extractInvestigationSubject(from goal: String) -> String? {
        // "Investigate the mysterious murders" -> "mysterious murders"
        // "Solve the puzzle of the ancient runes" -> "puzzle of the ancient runes"
        let patterns = [
            "investigate the (.+?)(?:\\s+in|\\s+at|$)",
            "solve the (.+?)(?:\\s+of|\\s+in|\\s+at|$)",
            "uncover the (.+?)(?:\\s+of|\\s+in|\\s+at|\\s+behind|$)",
            "discover the (.+?)(?:\\s+of|\\s+in|\\s+at|\\s+behind|$)"
        ]

        return extractUsingPatterns(patterns, from: goal)
    }

    private static func extractDiplomaticGoal(from goal: String) -> String? {
        // "Negotiate peace between rival tribes" -> "peace between rival tribes"
        // "Convince the king to support the rebellion" -> "king"
        let patterns = [
            "negotiate (.+?)(?:\\s+with|\\s+in|\\s+at|$)",
            "persuade the (.+?)(?:\\s+to|\\s+that|\\s+of|$)",
            "convince the (.+?)(?:\\s+to|\\s+that|\\s+of|$)"
        ]

        return extractUsingPatterns(patterns, from: goal)
    }

    // MARK: - Helper Methods

    private static func extractUsingPatterns(_ patterns: [String], from text: String) -> String? {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let extracted = String(text[range]).trimmingCharacters(in: .whitespaces)
                if !extracted.isEmpty {
                    return extracted
                }
            }
        }
        return nil
    }
}
