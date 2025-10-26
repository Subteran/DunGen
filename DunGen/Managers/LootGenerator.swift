import Foundation
import FoundationModels
import OSLog

@MainActor
final class LootGenerator {
    private let logger = Logger(subsystem: "com.logicchaos.DunGen", category: "LootGenerator")
    private let affixRegistry: AffixRegistry
    private let itemGenerator = ItemAffixGenerator()

    init(affixRegistry: AffixRegistry) {
        self.affixRegistry = affixRegistry
    }

    func determineItemRarity(difficulty: String, characterLevel: Int) -> String {
        let roll = Int.random(in: 1...100)
        let isBoss = difficulty.lowercased() == "boss"
        let isHard = difficulty.lowercased() == "hard"

        if isBoss {
            if roll <= 5 { return "legendary" }
            if roll <= 20 { return "epic" }
            if roll <= 45 { return "rare" }
            if roll <= 75 { return "uncommon" }
            return "common"
        } else if isHard {
            if roll <= 2 { return "legendary" }
            if roll <= 10 { return "epic" }
            if roll <= 25 { return "rare" }
            if roll <= 55 { return "uncommon" }
            return "common"
        } else {
            if roll <= 1 { return "legendary" }
            if roll <= 6 { return "epic" }
            if roll <= 16 { return "rare" }
            if roll <= 46 { return "uncommon" }
            return "common"
        }
    }

    func generateLoot(
        count: Int,
        difficulty: String,
        characterLevel: Int,
        characterClass: String,
        existingInventory: [ItemDefinition],
        equipmentSession: LanguageModelSession
    ) async throws -> [ItemDefinition] {
        var items: [ItemDefinition] = []

        let recentPrefixes = affixRegistry.getRecentItemPrefixes(limit: 10)
        let recentSuffixes = affixRegistry.getRecentItemSuffixes(limit: 10)

        var existingItemNames = Set<String>()
        for item in existingInventory {
            existingItemNames.insert(item.fullName)
        }

        for _ in 0..<count {
            let rarity = determineItemRarity(difficulty: difficulty, characterLevel: characterLevel)
            logger.debug("[Equipment] Pre-determined rarity: \(rarity)")

            let itemType = selectItemType(for: characterClass)
            let baseName = selectBaseName(for: itemType)

            let item = itemGenerator.generateAffixedItem(
                baseName: baseName,
                itemType: itemType,
                rarity: rarity,
                characterLevel: characterLevel,
                recentPrefixes: recentPrefixes,
                recentSuffixes: recentSuffixes
            )

            if existingItemNames.contains(item.fullName) {
                logger.warning("[Equipment] Duplicate item name: \(item.fullName), skipping")
                continue
            }

            existingItemNames.insert(item.fullName)

            if let prefix = item.prefix {
                affixRegistry.registerItemAffix(prefix)
            }
            if let suffix = item.suffix {
                affixRegistry.registerItemAffix(suffix)
            }

            logger.debug("[Equipment] Generated: \(item.fullName) (\(item.rarity))")
            items.append(item)
        }

        return items
    }

    private func selectItemType(for characterClass: String) -> String {
        let weaponWeight = 0.5
        let armorWeight = 0.3

        let roll = Double.random(in: 0...1)

        if roll < weaponWeight {
            return "weapon"
        } else if roll < weaponWeight + armorWeight {
            return "armor"
        } else {
            return "accessory"
        }
    }

    private func selectBaseName(for itemType: String) -> String {
        switch itemType.lowercased() {
        case "weapon":
            return ["Sword", "Axe", "Mace", "Dagger", "Spear", "Bow", "Staff", "Wand"].randomElement() ?? "Sword"
        case "armor":
            return ["Chestplate", "Helmet", "Gauntlets", "Boots", "Shield", "Cloak", "Bracers"].randomElement() ?? "Armor"
        case "accessory":
            return ["Ring", "Amulet", "Belt", "Talisman", "Pendant", "Brooch"].randomElement() ?? "Ring"
        default:
            return "Item"
        }
    }
}
