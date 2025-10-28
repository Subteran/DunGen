import Foundation
import FoundationModels
import OSLog

@MainActor
final class MonsterGenerator {
    private let affixRegistry: AffixRegistry
    private let affixGenerator = MonsterAffixGenerator()
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "MonsterGenerator")

    init(affixRegistry: AffixRegistry) {
        self.affixRegistry = affixRegistry
    }

    func generateMonster(
        session: LanguageModelSession,
        encounter: EncounterDetails,
        characterLevel: Int,
        location: String
    ) async throws -> MonsterDefinition? {
        let baseMonsters = selectBaseMonsters(for: characterLevel)
        guard let randomBase = baseMonsters.randomElement() else {
            return createFallbackMonster(from: MonsterDatabase.allMonsters[0])
        }

        let recentPrefixes = affixRegistry.getRecentMonsterPrefixes(limit: 10)
        let recentSuffixes = affixRegistry.getRecentMonsterSuffixes(limit: 10)

        let baseMonster = createBaseMonster(from: randomBase, characterLevel: characterLevel)

        let monster = affixGenerator.generateAffixedMonster(
            baseMonster: baseMonster,
            difficulty: encounter.difficulty,
            characterLevel: characterLevel,
            recentPrefixes: recentPrefixes,
            recentSuffixes: recentSuffixes
        )

        logger.debug("[Monster] Generated: \(monster.fullName) (HP: \(monster.hp), Dmg: \(monster.damage), Def: \(monster.defense))")

        registerAffixes(from: monster)

        return monster
    }

    private func selectBaseMonsters(for level: Int) -> [BaseMonster] {
        MonsterDatabase.allMonsters.filter { monster in
            if level <= 3 { return monster.baseHP <= 20 }
            else if level <= 7 { return monster.baseHP > 15 && monster.baseHP <= 60 }
            else if level <= 12 { return monster.baseHP > 45 && monster.baseHP <= 120 }
            else { return monster.baseHP > 80 }
        }
    }

    private func createBaseMonster(from base: BaseMonster, characterLevel: Int) -> MonsterDefinition {
        let scaledHP = scaleHP(base.baseHP, for: characterLevel)
        let scaledDefense = scaleDefense(base.baseDefense, for: characterLevel)

        return MonsterDefinition(
            baseName: base.name,
            prefix: nil,
            suffix: nil,
            hp: scaledHP,
            damage: base.baseDamage,
            defense: scaledDefense,
            abilities: generateAbilities(for: base.name, level: characterLevel),
            description: base.description
        )
    }

    private func createFallbackMonster(from base: BaseMonster) -> MonsterDefinition {
        MonsterDefinition(
            baseName: base.name,
            prefix: nil,
            suffix: nil,
            hp: base.baseHP,
            damage: base.baseDamage,
            defense: base.baseDefense,
            abilities: [],
            description: base.description
        )
    }

    private func scaleHP(_ baseHP: Int, for level: Int) -> Int {
        let multiplier = 1.0 + (Double(level - 1) * 0.15)
        return Int(Double(baseHP) * multiplier)
    }

    private func scaleDefense(_ baseDefense: Int, for level: Int) -> Int {
        baseDefense + (level / 3)
    }

    private func generateAbilities(for monsterName: String, level: Int) -> [String] {
        let abilityPool = [
            "Strike", "Bite", "Claw", "Smash", "Charge",
            "Roar", "Sweep", "Leap", "Tail Whip", "Gore"
        ]

        let count = min(1 + (level / 4), 3)
        return Array(abilityPool.shuffled().prefix(count))
    }

    private func registerAffixes(from monster: MonsterDefinition) {
        if let prefix = monster.prefix {
            affixRegistry.registerMonsterAffix(prefix)
        }
        if let suffix = monster.suffix {
            affixRegistry.registerMonsterAffix(suffix)
        }
    }

    /// Generates a complete boss monster for world generation (combat quests)
    /// Returns a full MonsterDefinition with affixes pre-applied
    /// This is used to pre-generate bosses so quest goals can use the exact affixed name
    func generateBossMonster(for characterLevel: Int) -> MonsterDefinition {
        let baseMonsters = selectBaseMonsters(for: characterLevel)
        guard let randomBase = baseMonsters.randomElement() else {
            return createFallbackMonster(from: MonsterDatabase.allMonsters[0])
        }

        let recentPrefixes = affixRegistry.getRecentMonsterPrefixes(limit: 10)
        let recentSuffixes = affixRegistry.getRecentMonsterSuffixes(limit: 10)

        let baseMonster = createBaseMonster(from: randomBase, characterLevel: characterLevel)

        // Generate with boss difficulty to ensure affixes are applied
        let bossMonster = affixGenerator.generateAffixedMonster(
            baseMonster: baseMonster,
            difficulty: "boss",
            characterLevel: characterLevel,
            recentPrefixes: recentPrefixes,
            recentSuffixes: recentSuffixes
        )

        logger.debug("[Monster] Pre-generated boss: \(bossMonster.fullName) (base: \(bossMonster.baseName))")

        // Register affixes for variety tracking
        registerAffixes(from: bossMonster)

        return bossMonster
    }

}
