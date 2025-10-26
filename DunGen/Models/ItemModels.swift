import Foundation
import FoundationModels

@Generable(description: "An item affix with consistent effects")
struct ItemAffix: Codable, Equatable {
    @Guide(description: "Affix name (e.g., 'Flaming', 'of the Bear', 'Sharp')")
    var name: String
    @Guide(description: "Affix type: prefix or suffix")
    var type: String
    @Guide(description: "Consistent effect description")
    var effect: String
}

@Generable(description: "A detailed equipment item")
struct ItemDefinition: Equatable, Identifiable {
    @Guide(description: "Base item name (e.g., 'Sword', 'Armor', 'Shield', 'Healing Potion')")
    var baseName: String
    @Guide(description: "Optional prefix affix")
    var prefix: ItemAffix?
    @Guide(description: "Optional suffix affix")
    var suffix: ItemAffix?
    @Guide(description: "Item type: weapon, armor, accessory, consumable")
    var itemType: String
    @Guide(description: "Detailed item description (2-3 sentences)")
    var description: String
    @Guide(description: "Item rarity: common, uncommon, rare, epic, legendary")
    var rarity: String
    @Guide(description: "For consumables only: the attribute affected (hp, gold, xp). Leave empty for non-consumables.")
    var consumableEffect: String?
    @Guide(description: "For consumables only: minimum value of the effect (e.g., 2 for 2-5 HP healing). Leave empty for non-consumables.")
    var consumableMinValue: Int?
    @Guide(description: "For consumables only: maximum value of the effect (e.g., 5 for 2-5 HP healing). Leave empty for non-consumables.")
    var consumableMaxValue: Int?

    var uuid: String = UUID().uuidString
    var id: String { uuid }
    var quantity: Int = 1

    var fullName: String {
        var name = ""
        if let prefix = prefix {
            name += "\(prefix.name) "
        }
        name += baseName
        if let suffix = suffix {
            name += " \(suffix.name)"
        }
        return name
    }

    var displayName: String {
        if quantity > 1 {
            return "\(fullName) (x\(quantity))"
        }
        return fullName
    }

    var effect: String {
        var effects: [String] = []
        if let prefix = prefix {
            effects.append(prefix.effect)
        }
        if let suffix = suffix {
            effects.append(suffix.effect)
        }
        return effects.joined(separator: ", ")
    }
}

extension ItemDefinition: Codable {
    enum CodingKeys: String, CodingKey {
        case baseName, prefix, suffix, itemType, description, rarity
        case consumableEffect, consumableMinValue, consumableMaxValue
        case uuid, quantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseName = try container.decode(String.self, forKey: .baseName)
        prefix = try container.decodeIfPresent(ItemAffix.self, forKey: .prefix)
        suffix = try container.decodeIfPresent(ItemAffix.self, forKey: .suffix)
        itemType = try container.decode(String.self, forKey: .itemType)
        description = try container.decode(String.self, forKey: .description)
        rarity = try container.decode(String.self, forKey: .rarity)
        consumableEffect = try container.decodeIfPresent(String.self, forKey: .consumableEffect)
        consumableMinValue = try container.decodeIfPresent(Int.self, forKey: .consumableMinValue)
        consumableMaxValue = try container.decodeIfPresent(Int.self, forKey: .consumableMaxValue)
        uuid = try container.decode(String.self, forKey: .uuid)
        quantity = try container.decodeIfPresent(Int.self, forKey: .quantity) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseName, forKey: .baseName)
        try container.encodeIfPresent(prefix, forKey: .prefix)
        try container.encodeIfPresent(suffix, forKey: .suffix)
        try container.encode(itemType, forKey: .itemType)
        try container.encode(description, forKey: .description)
        try container.encode(rarity, forKey: .rarity)
        try container.encodeIfPresent(consumableEffect, forKey: .consumableEffect)
        try container.encodeIfPresent(consumableMinValue, forKey: .consumableMinValue)
        try container.encodeIfPresent(consumableMaxValue, forKey: .consumableMaxValue)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(quantity, forKey: .quantity)
    }
}
