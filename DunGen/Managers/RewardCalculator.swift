import Foundation

struct RewardCalculator {

    static func calculateRewards(
        encounterType: String,
        difficulty: String,
        characterLevel: Int,
        currentHP: Int,
        maxHP: Int,
        isFinalEncounter: Bool,
        currentEncounter: Int = 0,
        totalEncounters: Int = 0,
        questCompleted: Bool = false
    ) -> ProgressionRewards {

        let type = encounterType.lowercased()
        let diff = difficulty.lowercased()

        // Final rewards are ONLY given when quest is actually completed
        // This prevents repeated boss rewards during overtime encounters
        if questCompleted && isFinalEncounter {
            return ProgressionRewards(
                xpGain: Int.random(in: 50...100),
                hpDelta: 0,
                goldGain: Int.random(in: 20...80),
                shouldDropLoot: false,
                itemDropCount: 0
            )
        }

        switch type {
        case "combat":
            return calculateCombatRewards(difficulty: diff, characterLevel: characterLevel)

        case "trap":
            return calculateTrapRewards(characterLevel: characterLevel)

        case "social":
            return ProgressionRewards(
                xpGain: Int.random(in: 2...5),
                hpDelta: 0,
                goldGain: 0,
                shouldDropLoot: false,
                itemDropCount: 0
            )

        case "exploration", "puzzle", "stealth", "chase":
            let hpRegen = (currentHP < maxHP) ? 1 : 0
            return ProgressionRewards(
                xpGain: 0,
                hpDelta: hpRegen,
                goldGain: 0,
                shouldDropLoot: false,
                itemDropCount: 0
            )

        case "final":
            return ProgressionRewards(
                xpGain: Int.random(in: 50...100),
                hpDelta: 0,
                goldGain: Int.random(in: 20...80),
                shouldDropLoot: false,
                itemDropCount: 0
            )

        default:
            return ProgressionRewards(
                xpGain: 0,
                hpDelta: 0,
                goldGain: 0,
                shouldDropLoot: false,
                itemDropCount: 0
            )
        }
    }

    private static func calculateCombatRewards(difficulty: String, characterLevel: Int) -> ProgressionRewards {
        let baseXP = 10 + (characterLevel * 2)

        let multiplier: Double
        let goldRange: ClosedRange<Int>
        let damageRange: ClosedRange<Int>
        let lootChance: Double
        let maxItems: Int

        switch difficulty {
        case "easy":
            multiplier = 0.5
            goldRange = 5...15
            damageRange = -3...(-1)
            lootChance = 0.3
            maxItems = 1

        case "hard":
            multiplier = 1.5
            goldRange = 20...50
            damageRange = -10...(-5)
            lootChance = 0.7
            maxItems = 1

        case "boss":
            multiplier = Double.random(in: 2.0...3.0)
            goldRange = 50...200
            damageRange = -20...(-8)
            lootChance = 1.0
            maxItems = Int.random(in: 1...2)

        default:
            multiplier = 1.0
            goldRange = 10...30
            damageRange = -8...(-3)
            lootChance = 0.5
            maxItems = 1
        }

        let xp = Int(Double(baseXP) * multiplier)
        let gold = Int.random(in: goldRange)
        let damage = Int.random(in: damageRange)
        let shouldDrop = Double.random(in: 0...1) < lootChance
        let itemCount = shouldDrop ? Int.random(in: 0...maxItems) : 0

        return ProgressionRewards(
            xpGain: xp,
            hpDelta: damage,
            goldGain: gold,
            shouldDropLoot: shouldDrop,
            itemDropCount: itemCount
        )
    }

    private static func calculateTrapRewards(characterLevel: Int) -> ProgressionRewards {
        let damage: Int

        switch characterLevel {
        case 1...2:
            damage = -Int.random(in: 1...2)
        case 3...5:
            damage = -Int.random(in: 2...4)
        case 6...9:
            damage = -Int.random(in: 3...7)
        default:
            damage = -Int.random(in: 5...10)
        }

        return ProgressionRewards(
            xpGain: 0,
            hpDelta: damage,
            goldGain: 0,
            shouldDropLoot: false,
            itemDropCount: 0
        )
    }
}
