import Foundation

enum LLMContextLevel {
    case minimal
    case standard
    case full
}

struct ContextBuilder {

    static func buildContext(
        for specialist: LLMSpecialist,
        character: CharacterProfile?,
        characterLevel: Int,
        adventure: AdventureProgress?,
        location: String,
        encounterType: String? = nil,
        difficulty: String? = nil,
        recentActions: String? = nil,
        encounterCounts: [String: Int]? = nil,
        questGoal: String? = nil,
        recentQuestTypes: [String]? = nil,
        questProgressGuidance: String? = nil,
        narrativeState: NarrativeState? = nil,
        locationQuestGoal: String? = nil
    ) -> String {

        switch specialist {
        case .encounter:
            return buildEncounterContext(
                encounterCounts: encounterCounts,
                questGoal: adventure?.questGoal
            )

        case .monsters:
            return buildMonsterContext(
                location: location,
                difficulty: difficulty ?? "normal",
                characterLevel: characterLevel
            )

        case .npc:
            return buildNPCContext(
                location: location,
                difficulty: difficulty ?? "normal"
            )

        case .adventure:
            return buildAdventureContext(
                character: character,
                characterLevel: characterLevel,
                adventure: adventure,
                location: location,
                encounterType: encounterType,
                difficulty: difficulty,
                recentActions: recentActions,
                encounterCounts: encounterCounts,
                recentQuestTypes: recentQuestTypes,
                questProgressGuidance: questProgressGuidance,
                narrativeState: narrativeState,
                locationQuestGoal: locationQuestGoal
            )

        case .equipment:
            return buildEquipmentContext(
                characterLevel: characterLevel,
                characterClass: character?.className ?? "Warrior",
                difficulty: difficulty ?? "normal"
            )

        default:
            return ""
        }
    }

    private static func buildEncounterContext(encounterCounts: [String: Int]?, questGoal: String?) -> String {
        var context = ""

        if let counts = encounterCounts, !counts.isEmpty {
            let total = counts.values.reduce(0, +)
            let topTypes = counts.sorted { $0.value > $1.value }.prefix(3)
                .map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            context = "Total encounters: \(total) (\(topTypes))"
        } else {
            context = "First encounter"
        }

        if let goal = questGoal, !goal.isEmpty {
            context += "\nQuest: \(goal)"
        }

        return context
    }

    private static func buildMonsterContext(
        location: String,
        difficulty: String,
        characterLevel: Int
    ) -> String {
        return "Location: \(location)\nDifficulty: \(difficulty)\nCharacter Level: \(characterLevel)"
    }

    private static func buildNPCContext(location: String, difficulty: String) -> String {
        return "Location: \(location)\nDifficulty: \(difficulty)"
    }

    private static func buildAdventureContext(
        character: CharacterProfile?,
        characterLevel: Int,
        adventure: AdventureProgress?,
        location: String,
        encounterType: String?,
        difficulty: String?,
        recentActions: String?,
        encounterCounts: [String: Int]?,
        recentQuestTypes: [String]?,
        questProgressGuidance: String?,
        narrativeState: NarrativeState?,
        locationQuestGoal: String?
    ) -> String {
        var lines: [String] = []

        if let character = character {
            lines.append("Character: \(character.name), Level \(characterLevel) \(character.className), HP: \(character.hp), Gold: \(character.gold)")
        }

        lines.append("Location: \(location)")

        if let adventure = adventure {
            lines.append("Quest: \(adventure.questGoal)")
            lines.append("Progress: Encounter \(adventure.currentEncounter) of \(adventure.totalEncounters)")
        } else if let questGoal = locationQuestGoal {
            lines.append("NEW ADVENTURE - FIRST ENCOUNTER - Use EXACT questGoal: \(questGoal)")
        } else {
            lines.append("NEW ADVENTURE - FIRST ENCOUNTER - Generate new quest goal for this location")
        }

        if let type = encounterType, let diff = difficulty {
            lines.append("Encounter Type: \(type) (difficulty: \(diff))")
        }

        // NOTE: With extended Adventure session (12 uses), the SDK transcript maintains
        // full conversation history automatically. We no longer need to manually pass:
        // - Recent actions (SDK remembers all player actions)
        // - Previous narratives (SDK remembers all responses)
        // - Encounter counts (SDK has full conversation history)
        // This simplification prevents redundant context and token waste.

        // Only include variety hint on previous narrative (not full text - SDK has it)
        if let adventure = adventure, !adventure.recentNarratives.isEmpty {
            lines.append("Prev narrative: \(String(adventure.recentNarratives.last?.prefix(60) ?? ""))")
        }

        // Add recent quest types for new quest generation (only if no current quest)
        if adventure == nil || adventure?.questGoal.isEmpty == true {
            if let questTypes = recentQuestTypes, !questTypes.isEmpty {
                lines.append("AVOID QUEST TYPES: \(questTypes.joined(separator: ", "))")
            }
        }

        // Add quest progression guidance if available
        if let guidance = questProgressGuidance, !guidance.isEmpty {
            lines.append(guidance)
        }

        // Add narrative state context
        if let narrative = narrativeState {
            let summary = narrative.getContextSummary()
            if !summary.isEmpty {
                lines.append(summary)
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func buildEquipmentContext(
        characterLevel: Int,
        characterClass: String,
        difficulty: String
    ) -> String {
        return "Character: Level \(characterLevel) \(characterClass)\nDifficulty: \(difficulty)"
    }
}
