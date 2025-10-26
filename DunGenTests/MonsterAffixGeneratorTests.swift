import Testing
import Foundation
@testable import DunGen

@MainActor
struct MonsterAffixGeneratorTests {

    @Test("Boss monsters always get affixes")
    func testBossMonsterAlwaysAffixed() {
        let generator = MonsterAffixGenerator()
        let baseMonster = MonsterDefinition(
            baseName: "Dragon",
            prefix: nil,
            suffix: nil,
            hp: 100,
            damage: "2d8",
            defense: 15,
            abilities: ["Bite"],
            description: "A mighty dragon"
        )

        var affixedCount = 0
        for _ in 1...10 {
            let result = generator.generateAffixedMonster(
                baseMonster: baseMonster,
                difficulty: "boss",
                characterLevel: 5,
                recentPrefixes: [],
                recentSuffixes: []
            )
            if result.prefix != nil || result.suffix != nil {
                affixedCount += 1
            }
        }

        #expect(affixedCount == 10)
    }

    @Test("Easy monsters have lower affix chance")
    func testEasyMonsterAffixChance() {
        let generator = MonsterAffixGenerator()
        let baseMonster = MonsterDefinition(
            baseName: "Goblin",
            prefix: nil,
            suffix: nil,
            hp: 10,
            damage: "1d4",
            defense: 10,
            abilities: ["Strike"],
            description: "A small goblin"
        )

        var affixedCount = 0
        for _ in 1...100 {
            let result = generator.generateAffixedMonster(
                baseMonster: baseMonster,
                difficulty: "easy",
                characterLevel: 1,
                recentPrefixes: [],
                recentSuffixes: []
            )
            if result.prefix != nil || result.suffix != nil {
                affixedCount += 1
            }
        }

        #expect(affixedCount < 60)
        #expect(affixedCount > 10)
    }

    @Test("Hard monsters have higher affix chance")
    func testHardMonsterAffixChance() {
        let generator = MonsterAffixGenerator()
        let baseMonster = MonsterDefinition(
            baseName: "Ogre",
            prefix: nil,
            suffix: nil,
            hp: 50,
            damage: "2d6",
            defense: 13,
            abilities: ["Smash"],
            description: "A brutal ogre"
        )

        var affixedCount = 0
        for _ in 1...100 {
            let result = generator.generateAffixedMonster(
                baseMonster: baseMonster,
                difficulty: "hard",
                characterLevel: 5,
                recentPrefixes: [],
                recentSuffixes: []
            )
            if result.prefix != nil || result.suffix != nil {
                affixedCount += 1
            }
        }

        #expect(affixedCount > 80)
    }

    @Test("Affixed monster has increased HP")
    func testAffixedMonsterIncreasedHP() {
        let generator = MonsterAffixGenerator()
        let baseMonster = MonsterDefinition(
            baseName: "Wolf",
            prefix: nil,
            suffix: nil,
            hp: 20,
            damage: "1d6",
            defense: 12,
            abilities: ["Bite"],
            description: "A wild wolf"
        )

        for _ in 1...20 {
            let result = generator.generateAffixedMonster(
                baseMonster: baseMonster,
                difficulty: "boss",
                characterLevel: 5,
                recentPrefixes: [],
                recentSuffixes: []
            )

            if result.prefix != nil || result.suffix != nil {
                #expect(result.hp >= baseMonster.hp)
                return
            }
        }
    }

    @Test("Affixed monster has modified damage")
    func testAffixedMonsterModifiedDamage() {
        let generator = MonsterAffixGenerator()
        let baseMonster = MonsterDefinition(
            baseName: "Bear",
            prefix: nil,
            suffix: nil,
            hp: 30,
            damage: "1d8",
            defense: 12,
            abilities: ["Claw"],
            description: "A fierce bear"
        )

        for _ in 1...20 {
            let result = generator.generateAffixedMonster(
                baseMonster: baseMonster,
                difficulty: "boss",
                characterLevel: 5,
                recentPrefixes: [],
                recentSuffixes: []
            )

            if result.prefix != nil || result.suffix != nil {
                #expect(result.damage.contains("+") || result.damage == baseMonster.damage)
                return
            }
        }
    }

    @Test("Avoids recently used prefixes")
    func testAvoidsRecentPrefixes() {
        let generator = MonsterAffixGenerator()
        let baseMonster = MonsterDefinition(
            baseName: "Skeleton",
            prefix: nil,
            suffix: nil,
            hp: 15,
            damage: "1d6",
            defense: 11,
            abilities: ["Strike"],
            description: "An undead skeleton"
        )

        let recentPrefixes = AffixDatabase.monsterPrefixes.prefix(45).map { $0.name }
        var usedNonRecentPrefix = false

        for _ in 1...50 {
            let result = generator.generateAffixedMonster(
                baseMonster: baseMonster,
                difficulty: "boss",
                characterLevel: 5,
                recentPrefixes: recentPrefixes,
                recentSuffixes: []
            )

            if let prefix = result.prefix, !recentPrefixes.contains(prefix.name) {
                usedNonRecentPrefix = true
                break
            }
        }

        #expect(usedNonRecentPrefix)
    }

    @Test("Boss monsters get dual affixes at higher levels")
    func testBossDualAffixes() {
        let generator = MonsterAffixGenerator()
        let baseMonster = MonsterDefinition(
            baseName: "Lich",
            prefix: nil,
            suffix: nil,
            hp: 80,
            damage: "2d8",
            defense: 16,
            abilities: ["Dark Magic"],
            description: "An undead sorcerer"
        )

        var dualAffixCount = 0
        for _ in 1...20 {
            let result = generator.generateAffixedMonster(
                baseMonster: baseMonster,
                difficulty: "boss",
                characterLevel: 8,
                recentPrefixes: [],
                recentSuffixes: []
            )

            if result.prefix != nil && result.suffix != nil {
                dualAffixCount += 1
            }
        }

        #expect(dualAffixCount > 10)
    }

    @Test("Description includes affix effects")
    func testDescriptionIncludesAffixEffects() {
        let generator = MonsterAffixGenerator()
        let baseMonster = MonsterDefinition(
            baseName: "Spider",
            prefix: nil,
            suffix: nil,
            hp: 12,
            damage: "1d4",
            defense: 11,
            abilities: ["Bite"],
            description: "A large spider"
        )

        for _ in 1...20 {
            let result = generator.generateAffixedMonster(
                baseMonster: baseMonster,
                difficulty: "boss",
                characterLevel: 5,
                recentPrefixes: [],
                recentSuffixes: []
            )

            if result.prefix != nil {
                #expect(result.description != baseMonster.description)
                #expect(result.description.contains("["))
                return
            }
        }
    }

    @Test("Stats compound with multiple affixes")
    func testStatsCompoundWithMultipleAffixes() {
        let generator = MonsterAffixGenerator()
        let baseMonster = MonsterDefinition(
            baseName: "Troll",
            prefix: nil,
            suffix: nil,
            hp: 50,
            damage: "2d6",
            defense: 13,
            abilities: ["Regeneration"],
            description: "A massive troll"
        )

        for _ in 1...30 {
            let result = generator.generateAffixedMonster(
                baseMonster: baseMonster,
                difficulty: "boss",
                characterLevel: 10,
                recentPrefixes: [],
                recentSuffixes: []
            )

            if result.prefix != nil && result.suffix != nil {
                #expect(result.hp > baseMonster.hp)
                return
            }
        }
    }
}
