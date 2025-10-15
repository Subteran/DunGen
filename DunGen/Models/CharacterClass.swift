import Foundation

enum CharacterClass: String, CaseIterable, Codable, Equatable {
    case rogue = "Rogue"
    case warrior = "Warrior"
    case mage = "Mage"
    case healer = "Healer"
    case paladin = "Paladin"
    case ranger = "Ranger"

    var allowedWeapons: Set<WeaponType> {
        switch self {
        case .rogue:
            return [.dagger, .shortsword, .rapier, .bow, .crossbow]
        case .warrior:
            return Set(WeaponType.allCases)
        case .mage:
            return [.dagger, .staff, .wand]
        case .healer:
            return [.staff, .mace, .club]
        case .paladin:
            return [.sword, .longsword, .greatsword, .axe, .battleaxe, .mace, .warhammer]
        case .ranger:
            return [.dagger, .shortsword, .sword, .axe, .mace, .bow, .crossbow]
        }
    }

    var allowedArmor: Set<ArmorType> {
        switch self {
        case .rogue:
            return [.cloth, .leather]
        case .warrior:
            return Set(ArmorType.allCases)
        case .mage:
            return [.cloth]
        case .healer:
            return Set(ArmorType.allCases)
        case .paladin:
            return [.mail, .plate]
        case .ranger:
            return [.leather, .mail]
        }
    }

    var usesSpells: Bool {
        self == .mage
    }

    var usesPrayers: Bool {
        self == .healer || self == .paladin
    }

    var description: String {
        switch self {
        case .rogue:
            return "A stealthy combatant using light weapons, cloth or leather armor, and ranged weapons"
        case .warrior:
            return "A versatile fighter capable of using any weapon and any armor"
        case .mage:
            return "A spellcaster wielding daggers, staves, or wands, protected by cloth armor"
        case .healer:
            return "A divine practitioner using staves or blunt weapons, any armor, and healing prayers"
        case .paladin:
            return "A holy warrior wielding swords, axes, or maces in mail or plate armor, empowered by prayers"
        case .ranger:
            return "A versatile scout using one-handed weapons, leather or mail armor, and ranged weapons"
        }
    }
}

enum WeaponType: String, CaseIterable, Codable, Equatable {
    case dagger = "Dagger"
    case shortsword = "Shortsword"
    case sword = "Sword"
    case longsword = "Longsword"
    case greatsword = "Greatsword"
    case rapier = "Rapier"
    case axe = "Axe"
    case battleaxe = "Battleaxe"
    case mace = "Mace"
    case warhammer = "Warhammer"
    case club = "Club"
    case staff = "Staff"
    case wand = "Wand"
    case bow = "Bow"
    case crossbow = "Crossbow"
}

enum ArmorType: String, CaseIterable, Codable, Equatable {
    case cloth = "Cloth"
    case leather = "Leather"
    case mail = "Mail"
    case plate = "Plate"
}

protocol CharacterClassProtocol {
    var characterClass: CharacterClass { get }
    func canUseWeapon(_ weapon: WeaponType) -> Bool
    func canUseArmor(_ armor: ArmorType) -> Bool
}

extension CharacterProfile: CharacterClassProtocol {
    var characterClass: CharacterClass {
        CharacterClass(rawValue: className) ?? .warrior
    }

    func canUseWeapon(_ weapon: WeaponType) -> Bool {
        characterClass.allowedWeapons.contains(weapon)
    }

    func canUseArmor(_ armor: ArmorType) -> Bool {
        characterClass.allowedArmor.contains(armor)
    }
}
