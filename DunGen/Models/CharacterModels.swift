import Foundation
import FoundationModels

@Generable(description: "A fantasy RPG character for a rogue-like text adventure")
struct CharacterProfile: Codable, Equatable {
    var name: String
    var race: String
    @Guide(description: "Class must be one of: Rogue, Warrior, Mage, Healer, Paladin, Ranger, Monk, Bard, Druid, Necromancer, Barbarian")
    var className: String

    @Guide(description: "Brief background story (1-2 sentences)")
    var backstory: String

    @Guide(description: "Primary attributes")
    var attributes: Attributes

    @Guide(description: "Current hit points", .range(1...30))
    var hp: Int

    @Guide(description: "Maximum hit points between 8 and 14", .range(1...30))
    var maxHP: Int

    @Guide(description: "Starting experience points between 0 and 10", .range(0...1000))
    var xp: Int

    @Guide(description: "Starting gold between 5 and 25", .range(0...10000))
    var gold: Int

    @Guide(description: "Starting equipment appropriate for the character's class. Rogue: light weapons, cloth/leather armor. Warrior: any equipment. Mage: dagger/staff/wand, cloth armor. Healer: staff/mace, any armor. Paladin: sword/axe/mace, mail/plate armor. Ranger: one-handed weapons, leather/mail armor, ranged weapon. Monk: quarterstaff/fists, cloth/leather armor. Bard: rapier/dagger, leather armor, musical instrument. Druid: staff/scimitar, leather armor, druidic focus. Necromancer: staff/dagger, cloth robes, skull focus. Barbarian: greataxe/greatsword, leather/hide armor.", .count(2...6))
    var inventory: [String]

    @Guide(description: "Class-specific abilities. Rogue: stealth/sneak attack. Warrior: combat techniques. Mage: arcane spells. Healer: healing prayers. Paladin: divine prayers. Ranger: tracking/nature skills. Monk: martial arts/ki. Bard: performance/inspiration. Druid: shapeshifting/nature magic. Necromancer: undead control/death magic. Barbarian: rage/primal power.", .count(1...5))
    var abilities: [String]

    @Guide(description: "Spells for Mage (arcane magic), Druid (nature magic), or Necromancer (death magic), prayers for Healer/Paladin (divine magic). Other classes have empty list.", .count(0...10))
    var spells: [String]

    @Generable(description: "Primary attributes for a character")
    struct Attributes: Codable, Equatable {
        @Guide(description: "Strength", .range(5...20)) var strength: Int
        @Guide(description: "Dexterity", .range(5...20)) var dexterity: Int
        @Guide(description: "Constitution", .range(5...20)) var constitution: Int
        @Guide(description: "Intelligence", .range(5...20)) var intelligence: Int
        @Guide(description: "Wisdom", .range(5...20)) var wisdom: Int
        @Guide(description: "Charisma", .range(5...20)) var charisma: Int
    }
}

@Generable(description: "A new character ability, spell, or prayer")
struct LevelReward: Codable {
    @Guide(description: "Name of the new ability, spell, or prayer")
    var name: String
}
