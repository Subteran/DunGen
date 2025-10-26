import Foundation

@MainActor
class MonsterAffixGenerator {

    func generateAffixedMonster(
        baseMonster: MonsterDefinition,
        difficulty: String,
        characterLevel: Int,
        recentPrefixes: [String],
        recentSuffixes: [String]
    ) -> MonsterDefinition {

        let shouldHaveAffix = determineAffixChance(difficulty: difficulty, characterLevel: characterLevel)

        guard shouldHaveAffix else {
            return baseMonster
        }

        let affixCount = determineAffixCount(difficulty: difficulty, characterLevel: characterLevel)

        var prefix: MonsterAffix?
        var suffix: MonsterAffix?
        var hpMultiplier: Double = 1.0
        var damageBonus: Int = 0
        var defenseBonus: Int = 0

        if affixCount >= 1 {
            if let prefixData = selectMonsterPrefix(avoiding: recentPrefixes) {
                prefix = MonsterAffix(name: prefixData.name, type: "prefix", effect: prefixData.effect)
                hpMultiplier *= prefixData.hpMultiplier
                damageBonus += prefixData.damageBonus
                defenseBonus += prefixData.defenseBonus
            }
        }

        if affixCount >= 2 {
            if let suffixData = selectMonsterSuffix(avoiding: recentSuffixes) {
                suffix = MonsterAffix(name: suffixData.name, type: "suffix", effect: suffixData.effect)
                hpMultiplier *= suffixData.hpMultiplier
                damageBonus += suffixData.damageBonus
                defenseBonus += suffixData.defenseBonus
            }
        }

        let modifiedHP = Int(Double(baseMonster.hp) * hpMultiplier)
        let modifiedDefense = baseMonster.defense + defenseBonus

        let modifiedDamage: String
        if damageBonus > 0 {
            modifiedDamage = "\(baseMonster.damage)+\(damageBonus)"
        } else {
            modifiedDamage = baseMonster.damage
        }

        var modifiedDescription = baseMonster.description
        if let prefix = prefix {
            modifiedDescription = "[\(prefix.effect)] \(modifiedDescription)"
        }
        if let suffix = suffix {
            modifiedDescription = "\(modifiedDescription) [\(suffix.effect)]"
        }

        return MonsterDefinition(
            baseName: baseMonster.baseName,
            prefix: prefix,
            suffix: suffix,
            hp: modifiedHP,
            damage: modifiedDamage,
            defense: modifiedDefense,
            abilities: baseMonster.abilities,
            description: modifiedDescription
        )
    }

    private func determineAffixChance(difficulty: String, characterLevel: Int) -> Bool {
        let baseChance: Double

        switch difficulty.lowercased() {
        case "easy":
            baseChance = 0.3
        case "normal":
            baseChance = 0.5
        case "hard":
            baseChance = 0.7
        case "boss":
            return true
        default:
            baseChance = 0.5
        }

        let levelBonus = min(Double(characterLevel) * 0.05, 0.3)
        let totalChance = min(baseChance + levelBonus, 0.95)

        return Double.random(in: 0...1) < totalChance
    }

    private func determineAffixCount(difficulty: String, characterLevel: Int) -> Int {
        switch difficulty.lowercased() {
        case "easy":
            return characterLevel >= 5 && Double.random(in: 0...1) < 0.3 ? 2 : 1
        case "normal":
            return characterLevel >= 5 && Double.random(in: 0...1) < 0.5 ? 2 : 1
        case "hard":
            return characterLevel >= 3 && Double.random(in: 0...1) < 0.7 ? 2 : 1
        case "boss":
            return characterLevel >= 3 ? 2 : 1
        default:
            return 1
        }
    }

    private func selectMonsterPrefix(avoiding recent: [String]) -> MonsterAffixData? {
        let available = AffixDatabase.monsterPrefixes.filter { !recent.contains($0.name) }
        return available.isEmpty ? AffixDatabase.randomMonsterPrefix() : available.randomElement()
    }

    private func selectMonsterSuffix(avoiding recent: [String]) -> MonsterAffixData? {
        let available = AffixDatabase.monsterSuffixes.filter { !recent.contains($0.name) }
        return available.isEmpty ? AffixDatabase.randomMonsterSuffix() : available.randomElement()
    }
}
