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
struct ItemDefinition: Codable, Equatable, Identifiable {
    @Guide(description: "Base item name (e.g., 'Sword', 'Armor', 'Shield')")
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

    var id: UUID = UUID()

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
        fullName
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
