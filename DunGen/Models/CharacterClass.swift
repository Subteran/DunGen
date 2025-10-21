import Foundation

enum CharacterClass: String, CaseIterable, Codable, Equatable {
    case rogue = "Rogue"
    case warrior = "Warrior"
    case mage = "Mage"
    case healer = "Healer"
    case paladin = "Paladin"
    case ranger = "Ranger"
    case monk = "Monk"
    case bard = "Bard"
    case druid = "Druid"
    case necromancer = "Necromancer"
    case barbarian = "Barbarian"
    case warlock = "Warlock"
    case sorcerer = "Sorcerer"
    case cleric = "Cleric"
    case assassin = "Assassin"
    case berserker = "Berserker"

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
        case .monk:
            return [.staff, .club]
        case .bard:
            return [.dagger, .rapier, .shortsword]
        case .druid:
            return [.staff, .club, .dagger]
        case .necromancer:
            return [.dagger, .staff, .wand]
        case .barbarian:
            return [.axe, .battleaxe, .greatsword, .warhammer]
        case .warlock:
            return [.dagger, .staff, .wand]
        case .sorcerer:
            return [.dagger, .staff, .wand]
        case .cleric:
            return [.mace, .warhammer, .staff, .club]
        case .assassin:
            return [.dagger, .shortsword, .rapier, .bow, .crossbow]
        case .berserker:
            return [.axe, .battleaxe, .greatsword, .warhammer, .club]
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
        case .monk:
            return [.cloth, .leather]
        case .bard:
            return [.cloth, .leather]
        case .druid:
            return [.cloth, .leather]
        case .necromancer:
            return [.cloth]
        case .barbarian:
            return [.cloth, .leather]
        case .warlock:
            return [.cloth, .leather]
        case .sorcerer:
            return [.cloth]
        case .cleric:
            return [.cloth, .leather, .mail]
        case .assassin:
            return [.cloth, .leather]
        case .berserker:
            return [.cloth, .leather]
        }
    }

    var usesSpells: Bool {
        self == .mage || self == .druid || self == .necromancer || self == .warlock || self == .sorcerer
    }

    var usesPrayers: Bool {
        self == .healer || self == .paladin || self == .cleric
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
        case .monk:
            return "A martial artist using staves or unarmed combat, wearing cloth or leather robes"
        case .bard:
            return "A performer using light weapons and leather armor, inspiring allies with music"
        case .druid:
            return "A nature mystic wielding staves and wearing leather armor, casting nature spells"
        case .necromancer:
            return "A dark mage using staves and cloth robes, commanding undead with death magic"
        case .barbarian:
            return "A primal warrior using heavy weapons and light armor, fueled by rage"
        case .warlock:
            return "A pact-bound caster wielding dark magic through eldritch power"
        case .sorcerer:
            return "An innate spellcaster channeling raw magical energy"
        case .cleric:
            return "A devoted priest wielding blunt weapons and divine magic"
        case .assassin:
            return "A deadly shadow using poisons, stealth, and precision strikes"
        case .berserker:
            return "A fearless warrior entering battle frenzy with brutal weapons"
        }
    }

    var gridPosition: (row: Int, column: Int) {
        switch self {
        case .rogue: return (0, 0)
        case .warrior: return (0, 1)
        case .mage: return (0, 2)
        case .healer: return (0, 3)
        case .paladin: return (1, 0)
        case .ranger: return (1, 1)
        case .monk: return (1, 2)
        case .bard: return (1, 3)
        case .druid: return (2, 0)
        case .necromancer: return (2, 1)
        case .barbarian: return (2, 2)
        case .warlock: return (2, 3)
        case .sorcerer: return (3, 0)
        case .cleric: return (3, 1)
        case .assassin: return (3, 2)
        case .berserker: return (3, 3)
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
