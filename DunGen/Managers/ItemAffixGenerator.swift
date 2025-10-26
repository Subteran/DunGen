import Foundation

@MainActor
class ItemAffixGenerator {

    func generateAffixedItem(
        baseName: String,
        itemType: String,
        rarity: String,
        characterLevel: Int,
        recentPrefixes: [String],
        recentSuffixes: [String]
    ) -> ItemDefinition {

        let affixCount = determineAffixCount(rarity: rarity)

        var prefix: ItemAffix?
        var suffix: ItemAffix?
        var totalDamageBonus: Int = 0
        var totalDefenseBonus: Int = 0
        var effects: [String] = []

        if affixCount >= 1 {
            if let prefixData = selectItemPrefix(avoiding: recentPrefixes) {
                prefix = ItemAffix(name: prefixData.name, type: "prefix", effect: prefixData.effect)
                if let dmg = prefixData.damageBonus {
                    totalDamageBonus += dmg
                }
                if let def = prefixData.defenseBonus {
                    totalDefenseBonus += def
                }
                effects.append(prefixData.effect)
            }
        }

        if affixCount >= 2 {
            if let suffixData = selectItemSuffix(avoiding: recentSuffixes) {
                suffix = ItemAffix(name: suffixData.name, type: "suffix", effect: suffixData.effect)
                if let dmg = suffixData.damageBonus {
                    totalDamageBonus += dmg
                }
                if let def = suffixData.defenseBonus {
                    totalDefenseBonus += def
                }
                effects.append(suffixData.effect)
            }
        }

        let description = generateDescription(
            baseName: baseName,
            itemType: itemType,
            rarity: rarity,
            effects: effects,
            damageBonus: totalDamageBonus,
            defenseBonus: totalDefenseBonus
        )

        return ItemDefinition(
            baseName: baseName,
            prefix: prefix,
            suffix: suffix,
            itemType: itemType,
            description: description,
            rarity: rarity,
            consumableEffect: nil,
            consumableMinValue: nil,
            consumableMaxValue: nil
        )
    }

    func generateConsumable(
        baseName: String,
        rarity: String,
        effect: String,
        minValue: Int,
        maxValue: Int
    ) -> ItemDefinition {
        let description = generateConsumableDescription(
            baseName: baseName,
            effect: effect,
            minValue: minValue,
            maxValue: maxValue
        )

        return ItemDefinition(
            baseName: baseName,
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: description,
            rarity: rarity,
            consumableEffect: effect,
            consumableMinValue: minValue,
            consumableMaxValue: maxValue
        )
    }

    private func determineAffixCount(rarity: String) -> Int {
        switch rarity.lowercased() {
        case "common":
            return Double.random(in: 0...1) < 0.2 ? 1 : 0
        case "uncommon":
            return Double.random(in: 0...1) < 0.5 ? 1 : 0
        case "rare":
            return Double.random(in: 0...1) < 0.3 ? 2 : 1
        case "epic":
            return Double.random(in: 0...1) < 0.7 ? 2 : 1
        case "legendary":
            return 2
        default:
            return 0
        }
    }

    private func selectItemPrefix(avoiding recent: [String]) -> ItemAffixData? {
        let available = AffixDatabase.itemPrefixes.filter { !recent.contains($0.name) }
        return available.isEmpty ? AffixDatabase.randomItemPrefix() : available.randomElement()
    }

    private func selectItemSuffix(avoiding recent: [String]) -> ItemAffixData? {
        let available = AffixDatabase.itemSuffixes.filter { !recent.contains($0.name) }
        return available.isEmpty ? AffixDatabase.randomItemSuffix() : available.randomElement()
    }

    private func generateDescription(
        baseName: String,
        itemType: String,
        rarity: String,
        effects: [String],
        damageBonus: Int,
        defenseBonus: Int
    ) -> String {
        var desc = "A \(rarity) \(itemType)"

        if !effects.isEmpty {
            desc += " with \(effects.joined(separator: " and "))"
        }

        var stats: [String] = []
        if damageBonus > 0 {
            stats.append("+\(damageBonus) damage")
        }
        if defenseBonus > 0 {
            stats.append("+\(defenseBonus) defense")
        }

        if !stats.isEmpty {
            desc += ". Provides \(stats.joined(separator: " and "))."
        } else {
            desc += "."
        }

        return desc
    }

    private func generateConsumableDescription(
        baseName: String,
        effect: String,
        minValue: Int,
        maxValue: Int
    ) -> String {
        switch effect.lowercased() {
        case "hp":
            return "Restores \(minValue)-\(maxValue) health points when consumed."
        case "gold":
            return "Contains \(minValue)-\(maxValue) gold pieces."
        case "xp":
            return "Grants \(minValue)-\(maxValue) experience points."
        default:
            return "A consumable item with mysterious properties."
        }
    }
}
