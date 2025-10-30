import Foundation
import OSLog

final class NarrativeProcessor {
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "NarrativeProcessor")

    func sanitizeNarration(_ text: String, for encounterType: String?, expectedMonster: MonsterDefinition? = nil) -> String {
        // Only remove spurious characters from malformed LLM output
        // Trust the LLM to generate appropriate narrative
        let cleaned = removeSpuriousCharacters(from: text)

        if cleaned.isEmpty && !text.isEmpty {
            logger.warning("[Sanitization] Entire narrative was removed! Original length: \(text.count)")
            logger.warning("[Sanitization] Original text: \(text.prefix(200))...")
            return text // Return original if we accidentally deleted everything
        }

        return cleaned
    }

    private func removeSpuriousCharacters(from text: String) -> String {
        var cleaned = text

        // FIRST: Remove everything after common JSON markers that appear mid-narrative
        // This handles cases like "narrative text... Monster: Chilling Goblin... ItemsAcquired: [], adventureProgress: {"
        let jsonMarkers = [
            "Monster:",
            "Combat:",
            "ItemsAcquired:",
            "itemsAcquired:",
            "adventureProgress:",
            "playerPrompt:",
            "suggestedActions:",
            "currentEnvironment:",
            "goldSpent:"
        ]

        for marker in jsonMarkers {
            if let range = cleaned.range(of: marker) {
                cleaned = String(cleaned[..<range.lowerBound])
                break
            }
        }

        // Remove stray JSON characters that might appear from malformed LLM output
        // Remove standalone curly braces (not part of emoji or formatting)
        cleaned = cleaned.replacingOccurrences(of: "\n{\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\n}\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "^\\{\\s*$", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "^\\}\\s*$", with: "", options: .regularExpression)

        // Remove standalone brackets
        cleaned = cleaned.replacingOccurrences(of: "\n[\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\n]\n", with: "\n")

        // Remove JSON field names that leak into narrative
        cleaned = cleaned.replacingOccurrences(of: "\"narration\"\\s*:\\s*\"", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\"playerPrompt\"\\s*:\\s*\"", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\"suggestedActions\"\\s*:\\s*", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\"currentEnvironment\"\\s*:\\s*\"", with: "", options: .regularExpression)

        // Remove lines that are CLEARLY JSON structure (be conservative)
        var lines = cleaned.components(separatedBy: "\n")
        lines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Only filter lines that are EXACT JSON field names at the start
            // Must start with the pattern to avoid false positives in narrative
            let jsonFieldStarts = [
                "\"narration\":",
                "\"playerPrompt\":",
                "\"suggestedActions\":",
                "\"currentEnvironment\":",
                "\"adventureProgress\":",
                "\"itemsAcquired\":",
                "\"goldSpent\":",
                // Also check for unquoted versions (malformed JSON)
                "narration:",
                "playerPrompt:",
                "suggestedActions:",
                "currentEnvironment:",
                "adventureProgress:",
                "itemsAcquired:",
                "goldSpent:",
            ]

            for pattern in jsonFieldStarts {
                if trimmed.lowercased().hasPrefix(pattern.lowercased()) {
                    return false
                }
            }

            // Filter out lines that are pure JSON syntax (exact match only)
            if trimmed == "{" || trimmed == "}" || trimmed == "[" || trimmed == "]" || trimmed == "," {
                return false
            }

            return true
        }
        cleaned = lines.joined(separator: "\n")

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    func smartTruncatePrompt(_ prompt: String, maxLength: Int) -> String {
        if prompt.count <= maxLength {
            return prompt
        }

        let lines = prompt.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []

        for line in lines {
            let lineLower = line.lowercased()

            let mustKeep = lineLower.contains("⚠") ||
                          lineLower.contains("stage-") ||
                          lineLower.contains("action:") ||
                          lineLower.contains("new adventure") ||
                          lineLower.contains("avoid quest types") ||
                          (lineLower.contains("quest:") && line.count < 120) ||
                          (lineLower.contains("loc:") && line.count < 50) ||
                          (lineLower.contains("enc:") && line.count < 50) ||
                          (lineLower.contains("char:") && line.count < 80) ||
                          (lineLower.starts(with: "hp:") || lineLower.contains(" hp:")) ||
                          lineLower.contains("monster:") ||
                          lineLower.contains("npc:")

            if mustKeep {
                result.append(line)
            }
        }

        let truncated = result.joined(separator: "\n")

        if truncated.count > maxLength {
            // If still too long, prioritize keeping encounter type and critical instructions
            var priorityLines: [String] = []
            var otherLines: [String] = []

            for line in result {
                let lineLower = line.lowercased()
                if lineLower.contains("enc:") ||
                   lineLower.contains("⚠") ||
                   lineLower.contains("stage-") ||
                   lineLower.contains("new adventure") ||
                   lineLower.contains("avoid quest types") ||
                   lineLower.contains("action:") {
                    priorityLines.append(line)
                } else {
                    otherLines.append(line)
                }
            }

            // Start with priority lines, add others until we hit limit
            var finalLines = priorityLines
            var currentLength = priorityLines.joined(separator: "\n").count

            for line in otherLines {
                if currentLength + line.count + 1 < maxLength {
                    finalLines.append(line)
                    currentLength += line.count + 1
                }
            }

            return finalLines.joined(separator: "\n")
        }

        return truncated
    }

    func extractKeywords(from text: String, isPlayerAction: Bool) -> String {
        let lowercased = text.lowercased()
        var keywords: [String] = []

        let actionVerbs = ["attack", "fight", "flee", "run", "talk", "speak", "search", "investigate",
                          "open", "take", "use", "cast", "drink", "eat", "hide", "sneak", "climb"]
        let entities = ["monster", "goblin", "rat", "skeleton", "zombie", "orc", "dragon",
                       "chest", "door", "trap", "room", "corridor", "stairs", "npc"]
        let outcomes = ["defeated", "killed", "found", "discovered", "took damage", "healed",
                       "gained", "lost", "escaped", "failed", "succeeded"]

        for verb in actionVerbs {
            if lowercased.contains(verb) {
                keywords.append(verb)
                break
            }
        }

        for entity in entities {
            if lowercased.contains(entity) {
                keywords.append(entity)
            }
        }

        if !isPlayerAction {
            for outcome in outcomes {
                if lowercased.contains(outcome) {
                    keywords.append(outcome)
                    break
                }
            }
        }

        return keywords.prefix(3).joined(separator: " ")
    }

    func generateEncounterSummary(narrative: String, encounterType: String, monster: MonsterDefinition?, npc: NPCDefinition?) -> String {
        var summary = ""

        if let monster = monster {
            summary = "fight \(monster.fullName)"
        } else if let npc = npc {
            summary = "meet \(npc.name)"
        } else {
            let keywords = extractKeywords(from: narrative, isPlayerAction: false)
            if !keywords.isEmpty {
                summary = keywords
            } else {
                summary = encounterType
            }
        }

        return String(summary.prefix(60))
    }
}
