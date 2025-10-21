import SwiftUI

struct PaperDollView: View {
    let character: CharacterProfile
    let detailedInventory: [ItemDefinition]
    let size: CGFloat

    init(character: CharacterProfile, detailedInventory: [ItemDefinition] = [], size: CGFloat = 200) {
        self.character = character
        self.detailedInventory = detailedInventory
        self.size = size
    }

    var body: some View {
        RaceClassSprite.spriteView(
            race: character.race,
            className: character.className,
            size: size
        )
        .frame(width: size, height: size)
    }
}

#Preview("Character Sprites") {
    let dwarfWarrior = CharacterProfile(
        name: "Thorin",
        race: "Dwarf",
        className: "Warrior",
        backstory: "A stout dwarf warrior from the mountain halls.",
        attributes: CharacterProfile.Attributes(
            strength: 16,
            dexterity: 12,
            constitution: 16,
            intelligence: 10,
            wisdom: 11,
            charisma: 9
        ),
        hp: 15,
        maxHP: 15,
        xp: 0,
        gold: 50,
        inventory: [],
        abilities: ["Power Attack", "Shield Bash"],
        spells: []
    )

    let dwarfMage = CharacterProfile(
        name: "Gandrin",
        race: "Elf",
        className: "Mage",
        backstory: "A wise dwarf mage.",
        attributes: CharacterProfile.Attributes(
            strength: 10,
            dexterity: 12,
            constitution: 14,
            intelligence: 16,
            wisdom: 13,
            charisma: 9
        ),
        hp: 12,
        maxHP: 12,
        xp: 0,
        gold: 30,
        inventory: [],
        abilities: [],
        spells: ["Fireball", "Magic Missile"]
    )

    let detailedInventory: [ItemDefinition] = []

    VStack(spacing: 20) {
        Text("Character Paper Dolls")
            .font(.title)

        HStack(spacing: 30) {
            VStack {
                PaperDollView(
                    character: dwarfWarrior,
                    detailedInventory: detailedInventory,
                    size: 150
                )
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

                Text("\(dwarfWarrior.name) the \(dwarfWarrior.className)")
                    .font(.caption)
                    .fontWeight(.bold)
            }

            VStack {
                PaperDollView(
                    character: dwarfMage,
                    detailedInventory: detailedInventory,
                    size: 150
                )
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

                Text("\(dwarfMage.name) the \(dwarfMage.className)")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }

        Text("Sprites from race/class sprite sheets")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
