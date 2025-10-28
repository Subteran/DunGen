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
        questProgressGuidance: String? = nil
    ) -> String {

        switch specialist {
        case .encounter:
            return buildEncounterContext(
                encounterCounts: encounterCounts
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
                questProgressGuidance: questProgressGuidance
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

    private static func buildEncounterContext(encounterCounts: [String: Int]?) -> String {
        guard let counts = encounterCounts, !counts.isEmpty else {
            return "First encounter"
        }

        let total = counts.values.reduce(0, +)
        let topTypes = counts.sorted { $0.value > $1.value }.prefix(3)
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")

        return "Total encounters: \(total) (\(topTypes))"
    }

    private static func buildMonsterContext(
        location: String,
        difficulty: String,
        characterLevel: Int
    ) -> String {
        return "Loc: \(location)\nDiff: \(difficulty)\nLvl: \(characterLevel)"
    }

    private static func buildNPCContext(location: String, difficulty: String) -> String {
        return "Loc: \(location)\nDiff: \(difficulty)"
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
        questProgressGuidance: String?
    ) -> String {
        var lines: [String] = []

        if let character = character {
            lines.append("Char: \(character.name) L\(characterLevel) \(character.className) HP:\(character.hp) G:\(character.gold)")
        }

        lines.append("Loc: \(location)")

        if let adventure = adventure {
            lines.append("Quest: \(adventure.questGoal)")
        } else {
            lines.append("NEW ADVENTURE - Generate new quest goal for this location")
        }

        if let type = encounterType, let diff = difficulty {
            lines.append("Enc: \(type) (\(diff))")
        }

        if let actions = recentActions, !actions.isEmpty {
            lines.append("Recent: \(actions)")
        }

        if let counts = encounterCounts, !counts.isEmpty {
            let total = counts.values.reduce(0, +)
            let summary = counts.sorted { $0.value > $1.value }.prefix(3)
                .map { "\($0.value) \($0.key)" }
                .joined(separator: ", ")
            lines.append("Hist: \(total) enc (\(summary))")
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

        return lines.joined(separator: "\n")
    }

    private static func buildEquipmentContext(
        characterLevel: Int,
        characterClass: String,
        difficulty: String
    ) -> String {
        return "Char: L\(characterLevel) \(characterClass)\nDiff: \(difficulty)"
    }
}
