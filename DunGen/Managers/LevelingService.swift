import Foundation

protocol LevelingServiceProtocol {
    func applyXPGain(_ xpGain: Int, to character: inout CharacterProfile) -> LevelUpOutcome
    func level(forXP xp: Int) -> Int
    func xpNeededForNextLevel(currentXP xp: Int) -> Int
}

struct LevelUpOutcome {
    let didLevelUp: Bool
    let newLevel: Int?
    let levelsGained: Int
    let hpGain: Int
    let statPointsGained: Int
    let logLine: String
    let needsNewAbility: Bool
}

final class DefaultLevelingService: LevelingServiceProtocol {

    private let baseXP = 100.0
    private let exponent = 1.5

    nonisolated init() {}

    func level(forXP xp: Int) -> Int {
        if xp < Int(baseXP) {
            return 1
        }
        let level = floor(log(Double(xp) / baseXP) / log(exponent)) + 1
        return max(1, Int(level))
    }

    func xpNeededForNextLevel(currentXP xp: Int) -> Int {
        let currentLevel = level(forXP: xp)
        let nextLevelXP = baseXP * pow(exponent, Double(currentLevel))
        return Int(nextLevelXP)
    }

    func applyXPGain(_ xpGain: Int, to character: inout CharacterProfile) -> LevelUpOutcome {
        let oldLevel = level(forXP: character.xp)
        character.xp += xpGain
        let newLevel = level(forXP: character.xp)

        if newLevel > oldLevel {
            let levelsGained = newLevel - oldLevel
            var totalHPGain = 0
            var totalStatPoints = 0

            for _ in 0..<levelsGained {
                let hpGain = rollHPGain(constitution: character.attributes.constitution)
                totalHPGain += hpGain
                character.maxHP += hpGain

                let statPointsToAward = Int.random(in: 1...3)
                totalStatPoints += statPointsToAward
                applyStatPoints(statPointsToAward, to: &character)
            }

            character.hp = character.maxHP

            let logLine = levelsGained > 1
                ? String(format: "⚡️ Level Up! You are now level %d and gained %d HP! (+%d levels)", newLevel, totalHPGain, levelsGained)
                : String(format: L10n.levelUpLineFormat, newLevel, totalHPGain)

            return LevelUpOutcome(
                didLevelUp: true,
                newLevel: newLevel,
                levelsGained: levelsGained,
                hpGain: totalHPGain,
                statPointsGained: totalStatPoints,
                logLine: logLine,
                needsNewAbility: true
            )
        } else {
            return LevelUpOutcome(
                didLevelUp: false,
                newLevel: nil,
                levelsGained: 0,
                hpGain: 0,
                statPointsGained: 0,
                logLine: "",
                needsNewAbility: false
            )
        }
    }

    private func rollHPGain(constitution: Int) -> Int {
        let constitutionModifier = (constitution - 10) / 2
        let baseRoll = Int.random(in: 1...8)
        return max(1, baseRoll + constitutionModifier)
    }

    private func applyStatPoints(_ points: Int, to character: inout CharacterProfile) {
        var remainingPoints = points
        let allStats = ["str", "dex", "con", "int", "wis", "cha"].shuffled()

        for stat in allStats where remainingPoints > 0 {
            switch stat {
            case "str":
                character.attributes.strength += 1
                remainingPoints -= 1
            case "dex":
                character.attributes.dexterity += 1
                remainingPoints -= 1
            case "con":
                character.attributes.constitution += 1
                remainingPoints -= 1
            case "int":
                character.attributes.intelligence += 1
                remainingPoints -= 1
            case "wis":
                character.attributes.wisdom += 1
                remainingPoints -= 1
            case "cha":
                character.attributes.charisma += 1
                remainingPoints -= 1
            default:
                break
            }
        }
    }
}
