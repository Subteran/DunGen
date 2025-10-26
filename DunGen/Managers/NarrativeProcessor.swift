import Foundation

final class NarrativeProcessor {
    func sanitizeNarration(_ text: String, for encounterType: String?) -> String {
        let forbidden = ["defeat", "defeated", "kill", "killed", "slay", "slain", "strike", "struck", "smite", "smitten", "crush", "crushed", "stab", "stabbed", "shoot", "shot", "damage", "wound", "wounded"]
        var sanitized = text
        if let type = encounterType, type == "combat" || type == "final" {
            for word in forbidden {
                sanitized = sanitized.replacingOccurrences(of: word, with: "confront", options: [.caseInsensitive, .regularExpression])
            }
        }

        sanitized = removeActionSuggestions(from: sanitized)
        return sanitized
    }

    private func removeActionSuggestions(from text: String) -> String {
        var lines = text.components(separatedBy: "\n")

        lines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()

            let hasActionPattern = lower.contains("you could") ||
                                  lower.contains("you can") ||
                                  lower.contains("you may") ||
                                  lower.contains("you might") ||
                                  lower.contains("will you") ||
                                  lower.contains("do you") ||
                                  lower.contains("would you") ||
                                  lower.contains("what do you") ||
                                  lower.contains("what will you") ||
                                  lower.contains("how do you")

            let isQuestionToPlayer = trimmed.hasSuffix("?") && (
                lower.contains("you") ||
                lower.starts(with: "will") ||
                lower.starts(with: "do") ||
                lower.starts(with: "would") ||
                lower.starts(with: "what") ||
                lower.starts(with: "how")
            )

            return !hasActionPattern && !isQuestionToPlayer
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func smartTruncatePrompt(_ prompt: String, maxLength: Int) -> String {
        if prompt.count <= maxLength {
            return prompt
        }

        let lines = prompt.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []

        for line in lines {
            let lineLower = line.lowercased()

            let mustKeep = lineLower.contains("critical") ||
                          lineLower.contains("quest stage") ||
                          lineLower.contains("player action:") ||
                          (lineLower.contains("quest:") && line.count < 120) ||
                          (lineLower.contains("location:") && line.count < 50) ||
                          (lineLower.contains("encounter:") && line.count < 50) ||
                          (lineLower.contains("character:") && line.count < 80) ||
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
                if lineLower.contains("encounter:") ||
                   lineLower.contains("critical") ||
                   lineLower.contains("quest stage") ||
                   lineLower.contains("player action:") {
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
