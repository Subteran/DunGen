import Testing
@testable import DunGen

@Suite("Character Class Tests")
struct CharacterClassTests {

    @Test("Rogue can use light weapons and ranged weapons")
    func rogueWeaponRestrictions() async throws {
        let character = CharacterProfile(
            name: "Shadow",
            race: "Elf",
            className: "Rogue",
            backstory: "A silent assassin.",
            attributes: .init(strength: 10, dexterity: 18, constitution: 12, intelligence: 14, wisdom: 10, charisma: 12),
            hp: 10, maxHP: 10, xp: 0, gold: 20,
            inventory: [],
            abilities: ["Sneak Attack"],
            spells: []
        )

        #expect(character.canUseWeapon(.dagger))
        #expect(character.canUseWeapon(.shortsword))
        #expect(character.canUseWeapon(.rapier))
        #expect(character.canUseWeapon(.bow))
        #expect(character.canUseWeapon(.crossbow))
        #expect(character.canUseWeapon(.greatsword) == false)
        #expect(character.canUseWeapon(.warhammer) == false)
    }

    @Test("Warrior can use any equipment")
    func warriorNoRestrictions() async throws {
        let character = CharacterProfile(
            name: "Conan",
            race: "Human",
            className: "Warrior",
            backstory: "A mighty barbarian.",
            attributes: .init(strength: 18, dexterity: 14, constitution: 16, intelligence: 10, wisdom: 10, charisma: 12),
            hp: 16, maxHP: 16, xp: 0, gold: 15,
            inventory: [],
            abilities: ["Battle Rage"],
            spells: []
        )

        #expect(character.canUseWeapon(.greatsword))
        #expect(character.canUseWeapon(.dagger))
        #expect(character.canUseWeapon(.bow))
        #expect(character.canUseArmor(.plate))
        #expect(character.canUseArmor(.cloth))
        #expect(character.canUseArmor(.leather))
    }

    @Test("Mage restricted to cloth armor and magic implements")
    func mageRestrictions() async throws {
        let character = CharacterProfile(
            name: "Gandalf",
            race: "Human",
            className: "Mage",
            backstory: "A wise wizard.",
            attributes: .init(strength: 8, dexterity: 12, constitution: 10, intelligence: 18, wisdom: 14, charisma: 13),
            hp: 8, maxHP: 8, xp: 0, gold: 10,
            inventory: [],
            abilities: [],
            spells: ["Fireball", "Magic Missile"]
        )

        #expect(character.canUseWeapon(.staff))
        #expect(character.canUseWeapon(.wand))
        #expect(character.canUseWeapon(.dagger))
        #expect(character.canUseWeapon(.sword) == false)
        #expect(character.canUseArmor(.cloth))
        #expect(character.canUseArmor(.leather) == false)
        #expect(character.canUseArmor(.plate) == false)
    }

    @Test("Healer can use blunt weapons and any armor")
    func healerRestrictions() async throws {
        let character = CharacterProfile(
            name: "Mercy",
            race: "Human",
            className: "Healer",
            backstory: "A devoted priest.",
            attributes: .init(strength: 12, dexterity: 10, constitution: 14, intelligence: 12, wisdom: 18, charisma: 15),
            hp: 12, maxHP: 12, xp: 0, gold: 12,
            inventory: [],
            abilities: [],
            spells: ["Heal", "Bless"]
        )

        #expect(character.canUseWeapon(.staff))
        #expect(character.canUseWeapon(.mace))
        #expect(character.canUseWeapon(.club))
        #expect(character.canUseWeapon(.sword) == false)
        #expect(character.canUseArmor(.cloth))
        #expect(character.canUseArmor(.plate))
    }

    @Test("Paladin uses heavy weapons and armor")
    func paladinRestrictions() async throws {
        let character = CharacterProfile(
            name: "Arthur",
            race: "Human",
            className: "Paladin",
            backstory: "A holy knight.",
            attributes: .init(strength: 16, dexterity: 10, constitution: 14, intelligence: 10, wisdom: 14, charisma: 16),
            hp: 14, maxHP: 14, xp: 0, gold: 25,
            inventory: [],
            abilities: ["Lay on Hands"],
            spells: ["Smite"]
        )

        #expect(character.canUseWeapon(.sword))
        #expect(character.canUseWeapon(.longsword))
        #expect(character.canUseWeapon(.axe))
        #expect(character.canUseWeapon(.mace))
        #expect(character.canUseWeapon(.bow) == false)
        #expect(character.canUseArmor(.mail))
        #expect(character.canUseArmor(.plate))
        #expect(character.canUseArmor(.cloth) == false)
    }

    @Test("Ranger uses one-handed and ranged weapons")
    func rangerRestrictions() async throws {
        let character = CharacterProfile(
            name: "Aragorn",
            race: "Human",
            className: "Ranger",
            backstory: "A skilled tracker.",
            attributes: .init(strength: 14, dexterity: 16, constitution: 14, intelligence: 12, wisdom: 14, charisma: 12),
            hp: 12, maxHP: 12, xp: 0, gold: 18,
            inventory: [],
            abilities: ["Track"],
            spells: []
        )

        #expect(character.canUseWeapon(.dagger))
        #expect(character.canUseWeapon(.shortsword))
        #expect(character.canUseWeapon(.sword))
        #expect(character.canUseWeapon(.bow))
        #expect(character.canUseWeapon(.crossbow))
        #expect(character.canUseWeapon(.greatsword) == false)
        #expect(character.canUseArmor(.leather))
        #expect(character.canUseArmor(.mail))
        #expect(character.canUseArmor(.plate) == false)
    }

    @Test("Character class enum has correct spell and prayer flags")
    func classAbilityTypes() async throws {
        #expect(CharacterClass.mage.usesSpells)
        #expect(CharacterClass.rogue.usesSpells == false)
        #expect(CharacterClass.warrior.usesSpells == false)

        #expect(CharacterClass.healer.usesPrayers)
        #expect(CharacterClass.paladin.usesPrayers)
        #expect(CharacterClass.mage.usesPrayers == false)
        #expect(CharacterClass.warrior.usesPrayers == false)
    }
}
