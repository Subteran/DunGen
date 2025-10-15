import Foundation

struct BaseMonster: Codable, Equatable {
    let name: String
    let category: String
    let baseHP: Int
    let baseDamage: String
    let baseDefense: Int
    let description: String
}

struct MonsterDatabase {
    static let allMonsters: [BaseMonster] = [
        BaseMonster(name: "Goblin", category: "humanoid", baseHP: 7, baseDamage: "1d6", baseDefense: 12, description: "Small, green-skinned raiders"),
        BaseMonster(name: "Kobold", category: "humanoid", baseHP: 5, baseDamage: "1d4", baseDefense: 10, description: "Cowardly reptilian creatures"),
        BaseMonster(name: "Orc", category: "humanoid", baseHP: 15, baseDamage: "1d8+2", baseDefense: 13, description: "Brutish warriors"),
        BaseMonster(name: "Skeleton", category: "undead", baseHP: 13, baseDamage: "1d6", baseDefense: 11, description: "Animated bones"),
        BaseMonster(name: "Zombie", category: "undead", baseHP: 22, baseDamage: "1d6+1", baseDefense: 8, description: "Shambling corpses"),

        BaseMonster(name: "Wolf", category: "beast", baseHP: 11, baseDamage: "1d6+1", baseDefense: 13, description: "Wild predator"),
        BaseMonster(name: "Bear", category: "beast", baseHP: 34, baseDamage: "1d8+4", baseDefense: 11, description: "Massive ursine hunter"),
        BaseMonster(name: "Giant Rat", category: "beast", baseHP: 7, baseDamage: "1d4", baseDefense: 12, description: "Disease-carrying vermin"),
        BaseMonster(name: "Giant Spider", category: "beast", baseHP: 26, baseDamage: "1d6", baseDefense: 14, description: "Venomous arachnid"),
        BaseMonster(name: "Dire Wolf", category: "beast", baseHP: 37, baseDamage: "2d6+3", baseDefense: 14, description: "Enormous predatory wolf"),

        BaseMonster(name: "Imp", category: "demon", baseHP: 10, baseDamage: "1d4+1", baseDefense: 13, description: "Mischievous devil"),
        BaseMonster(name: "Succubus", category: "demon", baseHP: 66, baseDamage: "1d6", baseDefense: 15, description: "Seductive fiend"),
        BaseMonster(name: "Hellhound", category: "demon", baseHP: 45, baseDamage: "1d8+1", baseDefense: 12, description: "Fiery demonic dog"),
        BaseMonster(name: "Lemure", category: "demon", baseHP: 13, baseDamage: "1d4", baseDefense: 7, description: "Mindless blob of evil"),
        BaseMonster(name: "Balor", category: "demon", baseHP: 262, baseDamage: "3d8+8", baseDefense: 19, description: "Massive demon lord"),

        BaseMonster(name: "Fire Elemental", category: "elemental", baseHP: 102, baseDamage: "2d6", baseDefense: 13, description: "Living flame"),
        BaseMonster(name: "Water Elemental", category: "elemental", baseHP: 114, baseDamage: "2d8+4", baseDefense: 14, description: "Animated water"),
        BaseMonster(name: "Earth Elemental", category: "elemental", baseHP: 126, baseDamage: "2d8+5", baseDefense: 17, description: "Living stone"),
        BaseMonster(name: "Air Elemental", category: "elemental", baseHP: 90, baseDamage: "2d8+2", baseDefense: 15, description: "Whirling wind"),
        BaseMonster(name: "Ice Elemental", category: "elemental", baseHP: 95, baseDamage: "2d6+3", baseDefense: 14, description: "Frozen entity"),

        BaseMonster(name: "Dragon Wyrmling", category: "dragon", baseHP: 75, baseDamage: "1d10+3", baseDefense: 17, description: "Young dragon"),
        BaseMonster(name: "Drake", category: "dragon", baseHP: 52, baseDamage: "1d10+2", baseDefense: 14, description: "Lesser dragon"),
        BaseMonster(name: "Wyvern", category: "dragon", baseHP: 110, baseDamage: "2d6+4", baseDefense: 13, description: "Two-legged dragon"),
        BaseMonster(name: "Ancient Dragon", category: "dragon", baseHP: 367, baseDamage: "4d10+10", baseDefense: 22, description: "Legendary wyrm"),
        BaseMonster(name: "Pseudodragon", category: "dragon", baseHP: 7, baseDamage: "1d4", baseDefense: 13, description: "Tiny dragon familiar"),

        BaseMonster(name: "Bandit", category: "humanoid", baseHP: 11, baseDamage: "1d6+1", baseDefense: 12, description: "Common thief"),
        BaseMonster(name: "Cultist", category: "humanoid", baseHP: 9, baseDamage: "1d6", baseDefense: 12, description: "Dark ritual follower"),
        BaseMonster(name: "Guard", category: "humanoid", baseHP: 11, baseDamage: "1d8+1", baseDefense: 16, description: "Armed soldier"),
        BaseMonster(name: "Assassin", category: "humanoid", baseHP: 78, baseDamage: "1d6+4", baseDefense: 15, description: "Deadly killer"),
        BaseMonster(name: "Berserker", category: "humanoid", baseHP: 67, baseDamage: "1d12+3", baseDefense: 13, description: "Raging warrior"),

        BaseMonster(name: "Troll", category: "giant", baseHP: 84, baseDamage: "1d6+4", baseDefense: 15, description: "Regenerating monster"),
        BaseMonster(name: "Ogre", category: "giant", baseHP: 59, baseDamage: "2d8+4", baseDefense: 11, description: "Dim-witted brute"),
        BaseMonster(name: "Hill Giant", category: "giant", baseHP: 105, baseDamage: "3d8+5", baseDefense: 13, description: "Massive humanoid"),
        BaseMonster(name: "Ettin", category: "giant", baseHP: 85, baseDamage: "2d8+5", baseDefense: 12, description: "Two-headed giant"),
        BaseMonster(name: "Cyclops", category: "giant", baseHP: 138, baseDamage: "3d8+6", baseDefense: 14, description: "One-eyed giant"),

        BaseMonster(name: "Ghost", category: "undead", baseHP: 45, baseDamage: "4d6", baseDefense: 11, description: "Spectral spirit"),
        BaseMonster(name: "Wraith", category: "undead", baseHP: 67, baseDamage: "4d8+3", baseDefense: 13, description: "Life-draining shade"),
        BaseMonster(name: "Vampire Spawn", category: "undead", baseHP: 82, baseDamage: "1d6+3", baseDefense: 15, description: "Lesser vampire"),
        BaseMonster(name: "Lich", category: "undead", baseHP: 135, baseDamage: "3d6", baseDefense: 17, description: "Undead sorcerer"),
        BaseMonster(name: "Mummy", category: "undead", baseHP: 58, baseDamage: "2d6+3", baseDefense: 11, description: "Preserved corpse"),

        BaseMonster(name: "Beholder", category: "aberration", baseHP: 180, baseDamage: "4d10", baseDefense: 18, description: "Eye tyrant"),
        BaseMonster(name: "Mind Flayer", category: "aberration", baseHP: 71, baseDamage: "2d10+4", baseDefense: 15, description: "Brain-eating horror"),
        BaseMonster(name: "Aboleth", category: "aberration", baseHP: 135, baseDamage: "3d6+5", baseDefense: 17, description: "Ancient aquatic terror"),
        BaseMonster(name: "Gelatinous Cube", category: "aberration", baseHP: 84, baseDamage: "3d6", baseDefense: 6, description: "Transparent ooze"),
        BaseMonster(name: "Rust Monster", category: "aberration", baseHP: 27, baseDamage: "1d8", baseDefense: 14, description: "Metal-eating creature"),

        BaseMonster(name: "Harpy", category: "monstrosity", baseHP: 38, baseDamage: "2d4+1", baseDefense: 11, description: "Singing bird-woman"),
        BaseMonster(name: "Manticore", category: "monstrosity", baseHP: 68, baseDamage: "1d8+3", baseDefense: 14, description: "Lion-scorpion hybrid"),
        BaseMonster(name: "Chimera", category: "monstrosity", baseHP: 114, baseDamage: "2d6+4", baseDefense: 14, description: "Three-headed beast"),
        BaseMonster(name: "Hydra", category: "monstrosity", baseHP: 172, baseDamage: "1d10+5", baseDefense: 15, description: "Multi-headed serpent"),
        BaseMonster(name: "Griffon", category: "monstrosity", baseHP: 59, baseDamage: "1d8+4", baseDefense: 12, description: "Eagle-lion hybrid"),

        BaseMonster(name: "Pixie", category: "fey", baseHP: 1, baseDamage: "1d4", baseDefense: 15, description: "Tiny trickster fairy"),
        BaseMonster(name: "Sprite", category: "fey", baseHP: 2, baseDamage: "1d4", baseDefense: 15, description: "Miniature fey"),
        BaseMonster(name: "Dryad", category: "fey", baseHP: 22, baseDamage: "1d4", baseDefense: 11, description: "Tree spirit"),
        BaseMonster(name: "Satyr", category: "fey", baseHP: 31, baseDamage: "1d6+1", baseDefense: 14, description: "Goat-legged reveler"),
        BaseMonster(name: "Hag", category: "fey", baseHP: 82, baseDamage: "2d8+3", baseDefense: 17, description: "Wicked crone"),

        BaseMonster(name: "Minotaur", category: "monstrosity", baseHP: 76, baseDamage: "2d12+4", baseDefense: 14, description: "Bull-headed humanoid"),
        BaseMonster(name: "Medusa", category: "monstrosity", baseHP: 127, baseDamage: "1d6+2", baseDefense: 15, description: "Petrifying gorgon"),
        BaseMonster(name: "Gorgon", category: "monstrosity", baseHP: 114, baseDamage: "2d12+5", baseDefense: 19, description: "Metal bull"),
        BaseMonster(name: "Cockatrice", category: "monstrosity", baseHP: 27, baseDamage: "1d4+1", baseDefense: 11, description: "Petrifying rooster"),
        BaseMonster(name: "Basilisk", category: "monstrosity", baseHP: 52, baseDamage: "2d6+3", baseDefense: 12, description: "Petrifying serpent"),

        BaseMonster(name: "Gnoll", category: "humanoid", baseHP: 22, baseDamage: "1d8+2", baseDefense: 15, description: "Hyena-headed raider"),
        BaseMonster(name: "Bugbear", category: "humanoid", baseHP: 27, baseDamage: "2d8+2", baseDefense: 16, description: "Hairy goblinoid"),
        BaseMonster(name: "Hobgoblin", category: "humanoid", baseHP: 11, baseDamage: "1d8+1", baseDefense: 18, description: "Disciplined goblin"),
        BaseMonster(name: "Troglodyte", category: "humanoid", baseHP: 13, baseDamage: "1d6", baseDefense: 11, description: "Reptilian caveman"),
        BaseMonster(name: "Lizardfolk", category: "humanoid", baseHP: 22, baseDamage: "1d6+2", baseDefense: 15, description: "Swamp reptilian"),

        BaseMonster(name: "Gargoyle", category: "construct", baseHP: 52, baseDamage: "1d6+2", baseDefense: 15, description: "Living stone statue"),
        BaseMonster(name: "Golem", category: "construct", baseHP: 178, baseDamage: "3d8+5", baseDefense: 20, description: "Magical automaton"),
        BaseMonster(name: "Animated Armor", category: "construct", baseHP: 33, baseDamage: "1d6+2", baseDefense: 18, description: "Enchanted suit"),
        BaseMonster(name: "Scarecrow", category: "construct", baseHP: 36, baseDamage: "2d6+1", baseDefense: 11, description: "Haunted straw figure"),
        BaseMonster(name: "Homunculus", category: "construct", baseHP: 5, baseDamage: "1d4", baseDefense: 13, description: "Artificial servant"),

        BaseMonster(name: "Banshee", category: "undead", baseHP: 58, baseDamage: "3d6", baseDefense: 12, description: "Wailing spirit"),
        BaseMonster(name: "Death Knight", category: "undead", baseHP: 180, baseDamage: "3d8+5", baseDefense: 20, description: "Cursed warrior"),
        BaseMonster(name: "Flameskull", category: "undead", baseHP: 40, baseDamage: "3d6", baseDefense: 13, description: "Flying burning skull"),
        BaseMonster(name: "Ghoul", category: "undead", baseHP: 22, baseDamage: "2d6+2", baseDefense: 12, description: "Flesh-eating corpse"),
        BaseMonster(name: "Revenant", category: "undead", baseHP: 136, baseDamage: "2d8+4", baseDefense: 13, description: "Vengeful corpse"),

        BaseMonster(name: "Displacer Beast", category: "monstrosity", baseHP: 85, baseDamage: "1d6+3", baseDefense: 13, description: "Illusory panther"),
        BaseMonster(name: "Owlbear", category: "monstrosity", baseHP: 59, baseDamage: "1d8+4", baseDefense: 13, description: "Owl-bear hybrid"),
        BaseMonster(name: "Bulette", category: "monstrosity", baseHP: 94, baseDamage: "4d12+4", baseDefense: 17, description: "Land shark"),
        BaseMonster(name: "Ankheg", category: "monstrosity", baseHP: 39, baseDamage: "2d6+3", baseDefense: 14, description: "Burrowing insect"),
        BaseMonster(name: "Phase Spider", category: "monstrosity", baseHP: 32, baseDamage: "1d10+3", baseDefense: 13, description: "Ethereal arachnid"),

        BaseMonster(name: "Roper", category: "monstrosity", baseHP: 93, baseDamage: "1d6", baseDefense: 20, description: "Tentacled stalactite"),
        BaseMonster(name: "Umber Hulk", category: "monstrosity", baseHP: 93, baseDamage: "3d8+5", baseDefense: 18, description: "Confusing tunneler"),
        BaseMonster(name: "Grick", category: "monstrosity", baseHP: 27, baseDamage: "2d6+3", baseDefense: 14, description: "Tentacled worm"),
        BaseMonster(name: "Cloaker", category: "aberration", baseHP: 78, baseDamage: "2d6+3", baseDefense: 14, description: "Living cloak"),
        BaseMonster(name: "Otyugh", category: "aberration", baseHP: 114, baseDamage: "1d8+5", baseDefense: 14, description: "Waste-dwelling beast"),

        BaseMonster(name: "Nightmare", category: "fiend", baseHP: 68, baseDamage: "2d8+4", baseDefense: 13, description: "Flaming demon horse"),
        BaseMonster(name: "Invisible Stalker", category: "elemental", baseHP: 104, baseDamage: "2d6+2", baseDefense: 14, description: "Unseen hunter"),
        BaseMonster(name: "Djinni", category: "elemental", baseHP: 161, baseDamage: "2d8+5", baseDefense: 17, description: "Air genie"),
        BaseMonster(name: "Efreeti", category: "elemental", baseHP: 200, baseDamage: "2d8+6", baseDefense: 17, description: "Fire genie"),
        BaseMonster(name: "Salamander", category: "elemental", baseHP: 90, baseDamage: "2d6+3", baseDefense: 15, description: "Fire serpent"),

        BaseMonster(name: "Naga", category: "monstrosity", baseHP: 127, baseDamage: "1d8+4", baseDefense: 18, description: "Serpent spellcaster"),
        BaseMonster(name: "Yuan-ti", category: "monstrosity", baseHP: 127, baseDamage: "1d6+3", baseDefense: 14, description: "Snake person"),
        BaseMonster(name: "Couatl", category: "celestial", baseHP: 97, baseDamage: "1d6+2", baseDefense: 19, description: "Feathered serpent"),
        BaseMonster(name: "Pegasus", category: "celestial", baseHP: 59, baseDamage: "2d6+4", baseDefense: 12, description: "Winged horse"),
        BaseMonster(name: "Unicorn", category: "celestial", baseHP: 67, baseDamage: "1d8+4", baseDefense: 12, description: "Sacred horned horse"),

        BaseMonster(name: "Shambling Mound", category: "plant", baseHP: 136, baseDamage: "2d8+4", baseDefense: 15, description: "Animated vegetation"),
        BaseMonster(name: "Treant", category: "plant", baseHP: 138, baseDamage: "3d6+6", baseDefense: 16, description: "Ancient tree guardian"),
        BaseMonster(name: "Myconid", category: "plant", baseHP: 22, baseDamage: "1d4+1", baseDefense: 10, description: "Mushroom person"),
        BaseMonster(name: "Vine Blight", category: "plant", baseHP: 26, baseDamage: "2d6+2", baseDefense: 12, description: "Corrupted plant"),
        BaseMonster(name: "Awakened Shrub", category: "plant", baseHP: 10, baseDamage: "1d4", baseDefense: 9, description: "Sentient bush")
    ]
}
