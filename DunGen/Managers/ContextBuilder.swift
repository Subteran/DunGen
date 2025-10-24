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
        questGoal: String? = nil
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
                encounterCounts: encounterCounts
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
        return "Location: \(location)\nDifficulty: \(difficulty)\nCharacter level: \(characterLevel)"
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
        encounterCounts: [String: Int]?
    ) -> String {
        var lines: [String] = []

        if let character = character {
            lines.append("Character: \(character.name) Lvl\(characterLevel) \(character.className) HP:\(character.hp) Gold:\(character.gold)")
        }

        lines.append("Location: \(location)")

        if let adventure = adventure {
            lines.append("Quest: \(adventure.questGoal)")
        }

        if let type = encounterType, let diff = difficulty {
            lines.append("Encounter: \(type) (\(diff))")
        }

        if let actions = recentActions, !actions.isEmpty {
            lines.append("Recent: \(actions)")
        }

        if let counts = encounterCounts, !counts.isEmpty {
            let total = counts.values.reduce(0, +)
            let summary = counts.sorted { $0.value > $1.value }.prefix(3)
                .map { "\($0.value) \($0.key)" }
                .joined(separator: ", ")
            lines.append("History: \(total) encounters (\(summary))")
        }

        return lines.joined(separator: "\n")
    }

    private static func buildEquipmentContext(
        characterLevel: Int,
        characterClass: String,
        difficulty: String
    ) -> String {
        return "Character: Lvl\(characterLevel) \(characterClass)\nDifficulty: \(difficulty)"
    }
}
