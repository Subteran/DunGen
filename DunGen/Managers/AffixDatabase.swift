import Foundation

struct MonsterAffixData {
    let name: String
    let type: String
    let effect: String
    let hpMultiplier: Double
    let damageBonus: Int
    let defenseBonus: Int
}

struct ItemAffixData {
    let name: String
    let type: String
    let effect: String
    let damageBonus: Int?
    let defenseBonus: Int?
    let attribute: String?
}

struct AffixDatabase {

    static let monsterPrefixes: [MonsterAffixData] = [
        MonsterAffixData(name: "Ancient", type: "prefix", effect: "+50% HP, +2 defense", hpMultiplier: 1.5, damageBonus: 0, defenseBonus: 2),
        MonsterAffixData(name: "Enraged", type: "prefix", effect: "+3 damage, +25% HP", hpMultiplier: 1.25, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "Armored", type: "prefix", effect: "+4 defense, +20% HP", hpMultiplier: 1.2, damageBonus: 0, defenseBonus: 4),
        MonsterAffixData(name: "Venomous", type: "prefix", effect: "+2 damage, poison attacks", hpMultiplier: 1.0, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "Corrupted", type: "prefix", effect: "+30% HP, +2 damage", hpMultiplier: 1.3, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "Frenzied", type: "prefix", effect: "+4 damage, -1 defense", hpMultiplier: 1.0, damageBonus: 4, defenseBonus: -1),
        MonsterAffixData(name: "Spectral", type: "prefix", effect: "+3 defense, ethereal", hpMultiplier: 1.0, damageBonus: 0, defenseBonus: 3),
        MonsterAffixData(name: "Titan", type: "prefix", effect: "+70% HP, +3 damage", hpMultiplier: 1.7, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "Plagued", type: "prefix", effect: "+1 damage, disease aura", hpMultiplier: 1.0, damageBonus: 1, defenseBonus: 0),
        MonsterAffixData(name: "Crystalline", type: "prefix", effect: "+5 defense, +10% HP", hpMultiplier: 1.1, damageBonus: 0, defenseBonus: 5),
        MonsterAffixData(name: "Shadow", type: "prefix", effect: "+2 damage, stealth", hpMultiplier: 1.0, damageBonus: 2, defenseBonus: 1),
        MonsterAffixData(name: "Blazing", type: "prefix", effect: "+3 damage, fire attacks", hpMultiplier: 1.0, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "Frozen", type: "prefix", effect: "+2 damage, ice attacks", hpMultiplier: 1.0, damageBonus: 2, defenseBonus: 1),
        MonsterAffixData(name: "Storm", type: "prefix", effect: "+2 damage, lightning", hpMultiplier: 1.0, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "Blood", type: "prefix", effect: "+40% HP, lifesteal", hpMultiplier: 1.4, damageBonus: 1, defenseBonus: 0),
        MonsterAffixData(name: "Cursed", type: "prefix", effect: "+30% HP, +1 damage", hpMultiplier: 1.3, damageBonus: 1, defenseBonus: 0),
        MonsterAffixData(name: "Radiant", type: "prefix", effect: "+2 defense, holy light", hpMultiplier: 1.1, damageBonus: 1, defenseBonus: 2),
        MonsterAffixData(name: "Void", type: "prefix", effect: "+3 damage, drain life", hpMultiplier: 1.0, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "Infernal", type: "prefix", effect: "+4 damage, hellfire", hpMultiplier: 1.0, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "Primal", type: "prefix", effect: "+50% HP, +2 damage", hpMultiplier: 1.5, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "Savage", type: "prefix", effect: "+3 damage, -1 defense", hpMultiplier: 1.1, damageBonus: 3, defenseBonus: -1),
        MonsterAffixData(name: "Elder", type: "prefix", effect: "+60% HP, +3 defense", hpMultiplier: 1.6, damageBonus: 0, defenseBonus: 3),
        MonsterAffixData(name: "Dire", type: "prefix", effect: "+40% HP, +2 damage", hpMultiplier: 1.4, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "Arcane", type: "prefix", effect: "+2 damage, magic", hpMultiplier: 1.0, damageBonus: 2, defenseBonus: 1),
        MonsterAffixData(name: "Unholy", type: "prefix", effect: "+3 damage, dark power", hpMultiplier: 1.2, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "Blessed", type: "prefix", effect: "+3 defense, divine", hpMultiplier: 1.2, damageBonus: 0, defenseBonus: 3),
        MonsterAffixData(name: "Rabid", type: "prefix", effect: "+4 damage, feral rage", hpMultiplier: 1.0, damageBonus: 4, defenseBonus: -1),
        MonsterAffixData(name: "Fortified", type: "prefix", effect: "+5 defense, +30% HP", hpMultiplier: 1.3, damageBonus: 0, defenseBonus: 5),
        MonsterAffixData(name: "Wild", type: "prefix", effect: "+2 damage, +20% HP", hpMultiplier: 1.2, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "Colossal", type: "prefix", effect: "+80% HP, +4 damage", hpMultiplier: 1.8, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "Nightmarish", type: "prefix", effect: "+3 damage, terror", hpMultiplier: 1.2, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "Toxic", type: "prefix", effect: "+2 damage, toxins", hpMultiplier: 1.0, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "Ethereal", type: "prefix", effect: "+4 defense, ghostly", hpMultiplier: 1.0, damageBonus: 0, defenseBonus: 4),
        MonsterAffixData(name: "Demonic", type: "prefix", effect: "+5 damage, chaos", hpMultiplier: 1.0, damageBonus: 5, defenseBonus: 0),
        MonsterAffixData(name: "Celestial", type: "prefix", effect: "+3 defense, heavenly", hpMultiplier: 1.3, damageBonus: 1, defenseBonus: 3),
        MonsterAffixData(name: "Volcanic", type: "prefix", effect: "+4 damage, lava", hpMultiplier: 1.0, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "Glacial", type: "prefix", effect: "+3 defense, ice armor", hpMultiplier: 1.2, damageBonus: 0, defenseBonus: 3),
        MonsterAffixData(name: "Thorned", type: "prefix", effect: "+2 defense, reflect", hpMultiplier: 1.0, damageBonus: 0, defenseBonus: 2),
        MonsterAffixData(name: "Mutated", type: "prefix", effect: "+35% HP, +2 damage", hpMultiplier: 1.35, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "Ironhide", type: "prefix", effect: "+6 defense", hpMultiplier: 1.0, damageBonus: 0, defenseBonus: 6),
        MonsterAffixData(name: "Berserk", type: "prefix", effect: "+5 damage, -2 defense", hpMultiplier: 1.1, damageBonus: 5, defenseBonus: -2),
        MonsterAffixData(name: "Unstable", type: "prefix", effect: "+3 damage, explosive", hpMultiplier: 1.0, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "Chilling", type: "prefix", effect: "+2 damage, slow", hpMultiplier: 1.0, damageBonus: 2, defenseBonus: 1),
        MonsterAffixData(name: "Molten", type: "prefix", effect: "+4 damage, burning", hpMultiplier: 1.0, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "Undying", type: "prefix", effect: "+90% HP, +2 defense", hpMultiplier: 1.9, damageBonus: 0, defenseBonus: 2),
        MonsterAffixData(name: "Apex", type: "prefix", effect: "+50% HP, +3 damage, +2 defense", hpMultiplier: 1.5, damageBonus: 3, defenseBonus: 2),
        MonsterAffixData(name: "Primordial", type: "prefix", effect: "+60% HP, +4 damage", hpMultiplier: 1.6, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "Mythic", type: "prefix", effect: "+70% HP, +3 defense", hpMultiplier: 1.7, damageBonus: 2, defenseBonus: 3),
        MonsterAffixData(name: "Champion", type: "prefix", effect: "+40% HP, +3 damage, +1 defense", hpMultiplier: 1.4, damageBonus: 3, defenseBonus: 1),
        MonsterAffixData(name: "Eldritch", type: "prefix", effect: "+3 damage, madness", hpMultiplier: 1.3, damageBonus: 3, defenseBonus: 0)
    ]

    static let monsterSuffixes: [MonsterAffixData] = [
        MonsterAffixData(name: "of Rage", type: "suffix", effect: "+4 damage", hpMultiplier: 1.0, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "of Power", type: "suffix", effect: "+3 damage, +20% HP", hpMultiplier: 1.2, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "of Protection", type: "suffix", effect: "+5 defense", hpMultiplier: 1.0, damageBonus: 0, defenseBonus: 5),
        MonsterAffixData(name: "of Destruction", type: "suffix", effect: "+5 damage", hpMultiplier: 1.0, damageBonus: 5, defenseBonus: 0),
        MonsterAffixData(name: "of Eternity", type: "suffix", effect: "+60% HP", hpMultiplier: 1.6, damageBonus: 0, defenseBonus: 0),
        MonsterAffixData(name: "of Shadows", type: "suffix", effect: "+2 damage, stealth", hpMultiplier: 1.0, damageBonus: 2, defenseBonus: 1),
        MonsterAffixData(name: "of Flames", type: "suffix", effect: "+3 damage, fire", hpMultiplier: 1.0, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "of Frost", type: "suffix", effect: "+2 damage, ice", hpMultiplier: 1.0, damageBonus: 2, defenseBonus: 1),
        MonsterAffixData(name: "of Lightning", type: "suffix", effect: "+3 damage, shock", hpMultiplier: 1.0, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "of Death", type: "suffix", effect: "+4 damage, necrotic", hpMultiplier: 1.0, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "of Life", type: "suffix", effect: "+70% HP, regeneration", hpMultiplier: 1.7, damageBonus: 0, defenseBonus: 0),
        MonsterAffixData(name: "of Fury", type: "suffix", effect: "+5 damage, -1 defense", hpMultiplier: 1.1, damageBonus: 5, defenseBonus: -1),
        MonsterAffixData(name: "of Steel", type: "suffix", effect: "+6 defense", hpMultiplier: 1.0, damageBonus: 0, defenseBonus: 6),
        MonsterAffixData(name: "of Terror", type: "suffix", effect: "+3 damage, fear", hpMultiplier: 1.2, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "of Venom", type: "suffix", effect: "+2 damage, poison", hpMultiplier: 1.0, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "of Corruption", type: "suffix", effect: "+30% HP, +2 damage", hpMultiplier: 1.3, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "of Madness", type: "suffix", effect: "+3 damage, chaos", hpMultiplier: 1.1, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "of Blood", type: "suffix", effect: "+40% HP, lifesteal", hpMultiplier: 1.4, damageBonus: 1, defenseBonus: 0),
        MonsterAffixData(name: "of Thorns", type: "suffix", effect: "+3 defense, reflect", hpMultiplier: 1.0, damageBonus: 0, defenseBonus: 3),
        MonsterAffixData(name: "of Domination", type: "suffix", effect: "+4 damage, +2 defense", hpMultiplier: 1.3, damageBonus: 4, defenseBonus: 2),
        MonsterAffixData(name: "of Ruin", type: "suffix", effect: "+6 damage", hpMultiplier: 1.0, damageBonus: 6, defenseBonus: 0),
        MonsterAffixData(name: "of Agony", type: "suffix", effect: "+3 damage, suffering", hpMultiplier: 1.0, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "of Havoc", type: "suffix", effect: "+5 damage, +20% HP", hpMultiplier: 1.2, damageBonus: 5, defenseBonus: 0),
        MonsterAffixData(name: "of Immortality", type: "suffix", effect: "+80% HP, +3 defense", hpMultiplier: 1.8, damageBonus: 0, defenseBonus: 3),
        MonsterAffixData(name: "of the Abyss", type: "suffix", effect: "+4 damage, void", hpMultiplier: 1.0, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "of the Storm", type: "suffix", effect: "+3 damage, lightning", hpMultiplier: 1.0, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "of the Inferno", type: "suffix", effect: "+4 damage, hellfire", hpMultiplier: 1.0, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "of the Glacier", type: "suffix", effect: "+4 defense, ice armor", hpMultiplier: 1.2, damageBonus: 0, defenseBonus: 4),
        MonsterAffixData(name: "of the Void", type: "suffix", effect: "+4 damage, drain", hpMultiplier: 1.0, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "of the Titan", type: "suffix", effect: "+70% HP, +3 damage", hpMultiplier: 1.7, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "of Carnage", type: "suffix", effect: "+6 damage, -1 defense", hpMultiplier: 1.0, damageBonus: 6, defenseBonus: -1),
        MonsterAffixData(name: "of the Beast", type: "suffix", effect: "+50% HP, +2 damage", hpMultiplier: 1.5, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "of the Damned", type: "suffix", effect: "+3 damage, cursed", hpMultiplier: 1.2, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "of Nightmares", type: "suffix", effect: "+4 damage, terror", hpMultiplier: 1.1, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "of Glory", type: "suffix", effect: "+40% HP, +3 damage, +2 defense", hpMultiplier: 1.4, damageBonus: 3, defenseBonus: 2),
        MonsterAffixData(name: "of Pestilence", type: "suffix", effect: "+2 damage, disease", hpMultiplier: 1.0, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "of Brutality", type: "suffix", effect: "+5 damage, +10% HP", hpMultiplier: 1.1, damageBonus: 5, defenseBonus: 0),
        MonsterAffixData(name: "of Wrath", type: "suffix", effect: "+6 damage", hpMultiplier: 1.0, damageBonus: 6, defenseBonus: 0),
        MonsterAffixData(name: "of the Colossus", type: "suffix", effect: "+90% HP, +4 defense", hpMultiplier: 1.9, damageBonus: 0, defenseBonus: 4),
        MonsterAffixData(name: "of the Demon", type: "suffix", effect: "+5 damage, chaos", hpMultiplier: 1.0, damageBonus: 5, defenseBonus: 0),
        MonsterAffixData(name: "of the Dragon", type: "suffix", effect: "+50% HP, +4 damage, +2 defense", hpMultiplier: 1.5, damageBonus: 4, defenseBonus: 2),
        MonsterAffixData(name: "of the Phoenix", type: "suffix", effect: "+60% HP, fire rebirth", hpMultiplier: 1.6, damageBonus: 2, defenseBonus: 0),
        MonsterAffixData(name: "of the Leviathan", type: "suffix", effect: "+100% HP, +5 damage", hpMultiplier: 2.0, damageBonus: 5, defenseBonus: 0),
        MonsterAffixData(name: "of the Maelstrom", type: "suffix", effect: "+4 damage, chaos storm", hpMultiplier: 1.0, damageBonus: 4, defenseBonus: 0),
        MonsterAffixData(name: "of the Grave", type: "suffix", effect: "+3 damage, undead", hpMultiplier: 1.3, damageBonus: 3, defenseBonus: 0),
        MonsterAffixData(name: "of Slaughter", type: "suffix", effect: "+7 damage", hpMultiplier: 1.0, damageBonus: 7, defenseBonus: 0),
        MonsterAffixData(name: "of the Conqueror", type: "suffix", effect: "+50% HP, +4 damage, +3 defense", hpMultiplier: 1.5, damageBonus: 4, defenseBonus: 3),
        MonsterAffixData(name: "of Oblivion", type: "suffix", effect: "+5 damage, erasure", hpMultiplier: 1.2, damageBonus: 5, defenseBonus: 0),
        MonsterAffixData(name: "of the Apocalypse", type: "suffix", effect: "+60% HP, +5 damage, +3 defense", hpMultiplier: 1.6, damageBonus: 5, defenseBonus: 3),
        MonsterAffixData(name: "of the Eternal", type: "suffix", effect: "+100% HP, +4 defense", hpMultiplier: 2.0, damageBonus: 0, defenseBonus: 4)
    ]

    static let itemPrefixes: [ItemAffixData] = [
        ItemAffixData(name: "Sharp", type: "prefix", effect: "+2 damage", damageBonus: 2, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Keen", type: "prefix", effect: "+3 damage", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Deadly", type: "prefix", effect: "+4 damage", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Brutal", type: "prefix", effect: "+5 damage", damageBonus: 5, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Heavy", type: "prefix", effect: "+2 damage, +1 defense", damageBonus: 2, defenseBonus: 1, attribute: nil),
        ItemAffixData(name: "Reinforced", type: "prefix", effect: "+2 defense", damageBonus: nil, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "Sturdy", type: "prefix", effect: "+3 defense", damageBonus: nil, defenseBonus: 3, attribute: nil),
        ItemAffixData(name: "Fortified", type: "prefix", effect: "+4 defense", damageBonus: nil, defenseBonus: 4, attribute: nil),
        ItemAffixData(name: "Masterwork", type: "prefix", effect: "+3 damage, +2 defense", damageBonus: 3, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "Flaming", type: "prefix", effect: "+3 damage, fire", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Frozen", type: "prefix", effect: "+2 damage, ice", damageBonus: 2, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Shocking", type: "prefix", effect: "+3 damage, lightning", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Venomous", type: "prefix", effect: "+2 damage, poison", damageBonus: 2, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Holy", type: "prefix", effect: "+3 damage, radiant", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Cursed", type: "prefix", effect: "+4 damage, necrotic", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Arcane", type: "prefix", effect: "+3 damage, magic", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Blessed", type: "prefix", effect: "+2 damage, +2 defense", damageBonus: 2, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "Dragon", type: "prefix", effect: "+5 damage, +1 defense", damageBonus: 5, defenseBonus: 1, attribute: nil),
        ItemAffixData(name: "Demon", type: "prefix", effect: "+5 damage, chaos", damageBonus: 5, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Shadow", type: "prefix", effect: "+3 damage, stealth", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Crystal", type: "prefix", effect: "+3 defense, +1 damage", damageBonus: 1, defenseBonus: 3, attribute: nil),
        ItemAffixData(name: "Radiant", type: "prefix", effect: "+3 damage, holy light", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Void", type: "prefix", effect: "+4 damage, void", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Storm", type: "prefix", effect: "+3 damage, thunder", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Infernal", type: "prefix", effect: "+4 damage, hellfire", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Celestial", type: "prefix", effect: "+3 damage, +2 defense", damageBonus: 3, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "Eldritch", type: "prefix", effect: "+4 damage, cosmic", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Primal", type: "prefix", effect: "+4 damage, nature", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Ethereal", type: "prefix", effect: "+2 damage, +3 defense", damageBonus: 2, defenseBonus: 3, attribute: nil),
        ItemAffixData(name: "Runic", type: "prefix", effect: "+3 damage, ancient magic", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Bloodstained", type: "prefix", effect: "+4 damage, lifesteal", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Grim", type: "prefix", effect: "+3 damage, death", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Wicked", type: "prefix", effect: "+3 damage, evil", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Volcanic", type: "prefix", effect: "+4 damage, lava", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Glacial", type: "prefix", effect: "+3 damage, +1 defense, ice", damageBonus: 3, defenseBonus: 1, attribute: nil),
        ItemAffixData(name: "Tempest", type: "prefix", effect: "+3 damage, wind", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Corrupted", type: "prefix", effect: "+4 damage, corruption", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Divine", type: "prefix", effect: "+4 damage, +2 defense", damageBonus: 4, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "Mythic", type: "prefix", effect: "+5 damage, +2 defense", damageBonus: 5, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "Legendary", type: "prefix", effect: "+6 damage, +3 defense", damageBonus: 6, defenseBonus: 3, attribute: nil),
        ItemAffixData(name: "Ancient", type: "prefix", effect: "+4 damage, +3 defense", damageBonus: 4, defenseBonus: 3, attribute: nil),
        ItemAffixData(name: "Eternal", type: "prefix", effect: "+5 damage, +3 defense", damageBonus: 5, defenseBonus: 3, attribute: nil),
        ItemAffixData(name: "Spectral", type: "prefix", effect: "+3 damage, ghostly", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Adamantine", type: "prefix", effect: "+5 defense, unbreakable", damageBonus: nil, defenseBonus: 5, attribute: nil),
        ItemAffixData(name: "Titanium", type: "prefix", effect: "+4 defense, +1 damage", damageBonus: 1, defenseBonus: 4, attribute: nil),
        ItemAffixData(name: "Mithril", type: "prefix", effect: "+3 defense, lightweight", damageBonus: nil, defenseBonus: 3, attribute: nil),
        ItemAffixData(name: "Obsidian", type: "prefix", effect: "+3 damage, volcanic glass", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Silver", type: "prefix", effect: "+2 damage, blessed metal", damageBonus: 2, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "Golden", type: "prefix", effect: "+3 damage, +1 defense", damageBonus: 3, defenseBonus: 1, attribute: nil),
        ItemAffixData(name: "Moonlight", type: "prefix", effect: "+3 damage, lunar", damageBonus: 3, defenseBonus: nil, attribute: nil)
    ]

    static let itemSuffixes: [ItemAffixData] = [
        ItemAffixData(name: "of Power", type: "suffix", effect: "+3 damage", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Might", type: "suffix", effect: "+4 damage", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Strength", type: "suffix", effect: "+2 damage", damageBonus: 2, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Protection", type: "suffix", effect: "+3 defense", damageBonus: nil, defenseBonus: 3, attribute: nil),
        ItemAffixData(name: "of Defense", type: "suffix", effect: "+2 defense", damageBonus: nil, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "of Warding", type: "suffix", effect: "+4 defense", damageBonus: nil, defenseBonus: 4, attribute: nil),
        ItemAffixData(name: "of the Bear", type: "suffix", effect: "+3 damage, +1 defense", damageBonus: 3, defenseBonus: 1, attribute: nil),
        ItemAffixData(name: "of the Tiger", type: "suffix", effect: "+4 damage", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of the Lion", type: "suffix", effect: "+5 damage", damageBonus: 5, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of the Dragon", type: "suffix", effect: "+6 damage, +2 defense", damageBonus: 6, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "of the Phoenix", type: "suffix", effect: "+4 damage, rebirth", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Fire", type: "suffix", effect: "+3 damage, burning", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Ice", type: "suffix", effect: "+2 damage, freezing", damageBonus: 2, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Lightning", type: "suffix", effect: "+3 damage, shocking", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Thunder", type: "suffix", effect: "+3 damage, thunder", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Venom", type: "suffix", effect: "+2 damage, poison", damageBonus: 2, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Slaying", type: "suffix", effect: "+5 damage", damageBonus: 5, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Piercing", type: "suffix", effect: "+3 damage, armor pierce", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Swiftness", type: "suffix", effect: "+2 damage, speed", damageBonus: 2, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Precision", type: "suffix", effect: "+3 damage, accuracy", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Destruction", type: "suffix", effect: "+6 damage", damageBonus: 6, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Ruin", type: "suffix", effect: "+5 damage, devastating", damageBonus: 5, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of the Fortress", type: "suffix", effect: "+5 defense", damageBonus: nil, defenseBonus: 5, attribute: nil),
        ItemAffixData(name: "of the Mountain", type: "suffix", effect: "+4 defense", damageBonus: nil, defenseBonus: 4, attribute: nil),
        ItemAffixData(name: "of the Titan", type: "suffix", effect: "+4 damage, +3 defense", damageBonus: 4, defenseBonus: 3, attribute: nil),
        ItemAffixData(name: "of the Gods", type: "suffix", effect: "+5 damage, +3 defense", damageBonus: 5, defenseBonus: 3, attribute: nil),
        ItemAffixData(name: "of Eternity", type: "suffix", effect: "+4 defense, eternal", damageBonus: nil, defenseBonus: 4, attribute: nil),
        ItemAffixData(name: "of Glory", type: "suffix", effect: "+4 damage, +2 defense", damageBonus: 4, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "of Victory", type: "suffix", effect: "+5 damage, triumph", damageBonus: 5, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Valor", type: "suffix", effect: "+3 damage, +2 defense", damageBonus: 3, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "of Honor", type: "suffix", effect: "+3 damage, +2 defense", damageBonus: 3, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "of Shadows", type: "suffix", effect: "+3 damage, stealth", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Light", type: "suffix", effect: "+3 damage, radiant", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Darkness", type: "suffix", effect: "+4 damage, void", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Chaos", type: "suffix", effect: "+4 damage, chaotic", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Order", type: "suffix", effect: "+3 damage, +2 defense", damageBonus: 3, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "of the Void", type: "suffix", effect: "+5 damage, void", damageBonus: 5, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of the Abyss", type: "suffix", effect: "+5 damage, darkness", damageBonus: 5, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of the Storm", type: "suffix", effect: "+4 damage, lightning", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of the Inferno", type: "suffix", effect: "+5 damage, fire", damageBonus: 5, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of the Glacier", type: "suffix", effect: "+3 damage, ice", damageBonus: 3, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Blood", type: "suffix", effect: "+4 damage, lifesteal", damageBonus: 4, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Death", type: "suffix", effect: "+5 damage, necrotic", damageBonus: 5, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Life", type: "suffix", effect: "+2 defense, healing", damageBonus: nil, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "of Rage", type: "suffix", effect: "+6 damage", damageBonus: 6, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of Fury", type: "suffix", effect: "+6 damage, berserker", damageBonus: 6, defenseBonus: nil, attribute: nil),
        ItemAffixData(name: "of the Apocalypse", type: "suffix", effect: "+7 damage, +3 defense", damageBonus: 7, defenseBonus: 3, attribute: nil),
        ItemAffixData(name: "of the Conqueror", type: "suffix", effect: "+6 damage, +2 defense", damageBonus: 6, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "of the Champion", type: "suffix", effect: "+5 damage, +2 defense", damageBonus: 5, defenseBonus: 2, attribute: nil),
        ItemAffixData(name: "of the Master", type: "suffix", effect: "+4 damage, +3 defense", damageBonus: 4, defenseBonus: 3, attribute: nil)
    ]

    static func randomMonsterPrefix() -> MonsterAffixData? {
        monsterPrefixes.randomElement()
    }

    static func randomMonsterSuffix() -> MonsterAffixData? {
        monsterSuffixes.randomElement()
    }

    static func randomItemPrefix() -> ItemAffixData? {
        itemPrefixes.randomElement()
    }

    static func randomItemSuffix() -> ItemAffixData? {
        itemSuffixes.randomElement()
    }

    static func getMonsterPrefix(name: String) -> MonsterAffixData? {
        monsterPrefixes.first { $0.name == name }
    }

    static func getMonsterSuffix(name: String) -> MonsterAffixData? {
        monsterSuffixes.first { $0.name == name }
    }

    static func getItemPrefix(name: String) -> ItemAffixData? {
        itemPrefixes.first { $0.name == name }
    }

    static func getItemSuffix(name: String) -> ItemAffixData? {
        itemSuffixes.first { $0.name == name }
    }
}
