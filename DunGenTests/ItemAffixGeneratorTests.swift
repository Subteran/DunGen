import Testing
import Foundation
@testable import DunGen

@MainActor
struct ItemAffixGeneratorTests {

    @Test("Common items have low affix chance")
    func testCommonItemAffixChance() {
        let generator = ItemAffixGenerator()
        var affixedCount = 0

        for _ in 1...100 {
            let item = generator.generateAffixedItem(
                baseName: "Sword",
                itemType: "weapon",
                rarity: "common",
                characterLevel: 1,
                recentPrefixes: [],
                recentSuffixes: []
            )

            if item.prefix != nil || item.suffix != nil {
                affixedCount += 1
            }
        }

        #expect(affixedCount < 40)
        #expect(affixedCount > 5)
    }

    @Test("Legendary items always have dual affixes")
    func testLegendaryItemDualAffixes() {
        let generator = ItemAffixGenerator()

        for _ in 1...20 {
            let item = generator.generateAffixedItem(
                baseName: "Blade",
                itemType: "weapon",
                rarity: "legendary",
                characterLevel: 10,
                recentPrefixes: [],
                recentSuffixes: []
            )

            #expect(item.prefix != nil)
            #expect(item.suffix != nil)
        }
    }

    @Test("Epic items have affixes")
    func testEpicItemHasAffixes() {
        let generator = ItemAffixGenerator()

        for _ in 1...20 {
            let item = generator.generateAffixedItem(
                baseName: "Armor",
                itemType: "armor",
                rarity: "epic",
                characterLevel: 7,
                recentPrefixes: [],
                recentSuffixes: []
            )

            let hasAffixes = item.prefix != nil || item.suffix != nil
            #expect(hasAffixes)
        }
    }

    @Test("Rare items often have affixes")
    func testRareItemAffixChance() {
        let generator = ItemAffixGenerator()
        var affixedCount = 0

        for _ in 1...100 {
            let item = generator.generateAffixedItem(
                baseName: "Staff",
                itemType: "weapon",
                rarity: "rare",
                characterLevel: 5,
                recentPrefixes: [],
                recentSuffixes: []
            )

            if item.prefix != nil || item.suffix != nil {
                affixedCount += 1
            }
        }

        #expect(affixedCount > 70)
    }

    @Test("Uncommon items sometimes have affixes")
    func testUncommonItemAffixChance() {
        let generator = ItemAffixGenerator()
        var affixedCount = 0

        for _ in 1...100 {
            let item = generator.generateAffixedItem(
                baseName: "Dagger",
                itemType: "weapon",
                rarity: "uncommon",
                characterLevel: 3,
                recentPrefixes: [],
                recentSuffixes: []
            )

            if item.prefix != nil || item.suffix != nil {
                affixedCount += 1
            }
        }

        #expect(affixedCount < 70)
        #expect(affixedCount > 30)
    }

    @Test("Item description includes base type and rarity")
    func testItemDescriptionStructure() {
        let generator = ItemAffixGenerator()
        let item = generator.generateAffixedItem(
            baseName: "Axe",
            itemType: "weapon",
            rarity: "rare",
            characterLevel: 5,
            recentPrefixes: [],
            recentSuffixes: []
        )

        #expect(item.description.contains("rare"))
        #expect(item.description.contains("weapon"))
    }

    @Test("Affixed items show stat bonuses in description")
    func testAffixedItemDescriptionShowsStats() {
        let generator = ItemAffixGenerator()

        for _ in 1...20 {
            let item = generator.generateAffixedItem(
                baseName: "Mace",
                itemType: "weapon",
                rarity: "legendary",
                characterLevel: 8,
                recentPrefixes: [],
                recentSuffixes: []
            )

            let hasStatInfo = item.description.contains("damage") || item.description.contains("defense")
            #expect(hasStatInfo)
        }
    }

    @Test("Avoids recently used prefixes")
    func testAvoidsRecentPrefixes() {
        let generator = ItemAffixGenerator()
        let recentPrefixes = AffixDatabase.itemPrefixes.prefix(45).map { $0.name }

        var usedNonRecentPrefix = false
        for _ in 1...50 {
            let item = generator.generateAffixedItem(
                baseName: "Sword",
                itemType: "weapon",
                rarity: "legendary",
                characterLevel: 10,
                recentPrefixes: recentPrefixes,
                recentSuffixes: []
            )

            if let prefix = item.prefix, !recentPrefixes.contains(prefix.name) {
                usedNonRecentPrefix = true
                break
            }
        }

        #expect(usedNonRecentPrefix)
    }

    @Test("Avoids recently used suffixes")
    func testAvoidsRecentSuffixes() {
        let generator = ItemAffixGenerator()
        let recentSuffixes = AffixDatabase.itemSuffixes.prefix(45).map { $0.name }

        var usedNonRecentSuffix = false
        for _ in 1...50 {
            let item = generator.generateAffixedItem(
                baseName: "Shield",
                itemType: "armor",
                rarity: "legendary",
                characterLevel: 10,
                recentPrefixes: [],
                recentSuffixes: recentSuffixes
            )

            if let suffix = item.suffix, !recentSuffixes.contains(suffix.name) {
                usedNonRecentSuffix = true
                break
            }
        }

        #expect(usedNonRecentSuffix)
    }

    @Test("Item effect combines prefix and suffix effects")
    func testItemEffectCombination() {
        let generator = ItemAffixGenerator()

        for _ in 1...20 {
            let item = generator.generateAffixedItem(
                baseName: "Ring",
                itemType: "accessory",
                rarity: "legendary",
                characterLevel: 10,
                recentPrefixes: [],
                recentSuffixes: []
            )

            if item.prefix != nil && item.suffix != nil {
                #expect(!item.effect.isEmpty)
                #expect(item.effect.contains(","))
                return
            }
        }
    }

    @Test("Consumable generation works correctly")
    func testConsumableGeneration() {
        let generator = ItemAffixGenerator()
        let potion = generator.generateConsumable(
            baseName: "Healing Potion",
            rarity: "common",
            effect: "hp",
            minValue: 5,
            maxValue: 10
        )

        #expect(potion.baseName == "Healing Potion")
        #expect(potion.itemType == "consumable")
        #expect(potion.consumableEffect == "hp")
        #expect(potion.consumableMinValue == 5)
        #expect(potion.consumableMaxValue == 10)
        #expect(potion.description.contains("5-10"))
    }

    @Test("Full name includes prefix and suffix")
    func testFullNameConstruction() {
        let generator = ItemAffixGenerator()

        for _ in 1...20 {
            let item = generator.generateAffixedItem(
                baseName: "Bow",
                itemType: "weapon",
                rarity: "legendary",
                characterLevel: 10,
                recentPrefixes: [],
                recentSuffixes: []
            )

            if let prefix = item.prefix, let suffix = item.suffix {
                #expect(item.fullName.contains(prefix.name))
                #expect(item.fullName.contains("Bow"))
                #expect(item.fullName.contains(suffix.name))
                return
            }
        }
    }

    @Test("Rarity affects affix probability distribution")
    func testRarityAffectsAffixDistribution() {
        let generator = ItemAffixGenerator()

        var commonDual = 0
        var legendaryDual = 0

        for _ in 1...100 {
            let common = generator.generateAffixedItem(
                baseName: "Item",
                itemType: "weapon",
                rarity: "common",
                characterLevel: 5,
                recentPrefixes: [],
                recentSuffixes: []
            )
            if common.prefix != nil && common.suffix != nil {
                commonDual += 1
            }

            let legendary = generator.generateAffixedItem(
                baseName: "Item",
                itemType: "weapon",
                rarity: "legendary",
                characterLevel: 5,
                recentPrefixes: [],
                recentSuffixes: []
            )
            if legendary.prefix != nil && legendary.suffix != nil {
                legendaryDual += 1
            }
        }

        #expect(legendaryDual == 100)
        #expect(commonDual < 10)
    }

    @Test("Different item types generate correctly")
    func testDifferentItemTypes() {
        let generator = ItemAffixGenerator()

        let weapon = generator.generateAffixedItem(
            baseName: "Sword",
            itemType: "weapon",
            rarity: "rare",
            characterLevel: 5,
            recentPrefixes: [],
            recentSuffixes: []
        )
        #expect(weapon.itemType == "weapon")

        let armor = generator.generateAffixedItem(
            baseName: "Helmet",
            itemType: "armor",
            rarity: "rare",
            characterLevel: 5,
            recentPrefixes: [],
            recentSuffixes: []
        )
        #expect(armor.itemType == "armor")

        let accessory = generator.generateAffixedItem(
            baseName: "Ring",
            itemType: "accessory",
            rarity: "rare",
            characterLevel: 5,
            recentPrefixes: [],
            recentSuffixes: []
        )
        #expect(accessory.itemType == "accessory")
    }
}
