import SwiftUI

struct CombatView: View {
    let monster: MonsterDefinition
    let currentMonsterHP: Int
    let character: CharacterProfile
    let detailedInventory: [ItemDefinition]
    let onAction: (CombatAction) -> Void
    let onFlee: () -> Void

    @State private var selectedAbility: String?

    enum CombatAction {
        case attack
        case useAbility(String)
        case useSpell(String)
        case usePrayer(String)
        case useItem(String)
        case flee
        case surrender
    }

    var body: some View {
        VStack(spacing: 0) {
            monsterSection

            Divider()

            characterSection

            Divider()

            actionsSection
        }
        .navigationTitle("Combat")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monsterSection: some View {
        VStack(spacing: 12) {
            Text(monster.fullName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.red)

            Text(monster.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 20) {
                StatBadge(label: "HP", value: "\(currentMonsterHP)/\(monster.hp)", color: .red)
                StatBadge(label: "DMG", value: monster.damage, color: .orange)
                StatBadge(label: "DEF", value: "\(monster.defense)", color: .blue)
            }

            if !monster.abilities.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Abilities:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    ForEach(monster.abilities, id: \.self) { ability in
                        Text("• \(ability)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Color.red.opacity(0.1))
    }

    private var characterSection: some View {
        VStack(spacing: 12) {
            Text(character.name)
                .font(.headline)

            HStack(spacing: 20) {
                StatBadge(label: "HP", value: "\(character.hp)", color: .green)
                StatBadge(label: "LVL", value: "\(character.attributes.strength)", color: .purple)
            }
        }
        .padding(.vertical, 12)
    }

    private var actionsSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                Button {
                    onAction(.attack)
                } label: {
                    ActionButton(title: "⚔️ Attack", subtitle: "Basic attack")
                }

                if !character.abilities.isEmpty {
                    DisclosureGroup("⚡️ Abilities (\(character.abilities.count))") {
                        VStack(spacing: 8) {
                            ForEach(character.abilities, id: \.self) { ability in
                                Button {
                                    onAction(.useAbility(ability))
                                } label: {
                                    ActionButton(title: ability, subtitle: "Use ability")
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .tint(.primary)
                }

                if !character.spells.isEmpty {
                    DisclosureGroup("📜 Spells (\(character.spells.count))") {
                        VStack(spacing: 8) {
                            ForEach(character.spells, id: \.self) { spell in
                                Button {
                                    onAction(.useSpell(spell))
                                } label: {
                                    ActionButton(title: spell, subtitle: "Cast spell")
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .tint(.primary)
                }

                if !consumableItems.isEmpty {
                    DisclosureGroup("🧪 Items (\(consumableItems.count))") {
                        VStack(spacing: 8) {
                            ForEach(consumableItems) { item in
                                Button {
                                    onAction(.useItem(item.fullName))
                                } label: {
                                    ActionButton(title: item.fullName, subtitle: itemEffect(item), color: .green)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .tint(.primary)
                }

                Divider()
                    .padding(.vertical, 8)

                Button {
                    onAction(.flee)
                } label: {
                    ActionButton(title: "🏃 Flee", subtitle: "Attempt to escape", color: .orange)
                }

                Button {
                    onAction(.surrender)
                } label: {
                    ActionButton(title: "🏳️ Surrender", subtitle: "Give up (death)", color: .red)
                }
            }
            .padding()
        }
    }

    private var consumableItems: [ItemDefinition] {
        detailedInventory.filter { item in
            !(item.consumableEffect ?? "").isEmpty
        }
    }

    private func itemEffect(_ item: ItemDefinition) -> String {
        guard let effect = item.consumableEffect else {
            return "Use item"
        }

        let min = item.consumableMinValue ?? 0
        let max = item.consumableMaxValue ?? 0

        switch effect.lowercased() {
        case "hp":
            return "Restore \(min)-\(max) HP"
        case "gold":
            return "Gain \(min)-\(max) gold"
        case "xp":
            return "Gain \(min)-\(max) XP"
        default:
            return "Use item"
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(minWidth: 60)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ActionButton: View {
    let title: String
    let subtitle: String
    var color: Color = .blue

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(10)
        .foregroundStyle(.primary)
    }
}

#Preview {
    NavigationStack {
        CombatView(
            monster: MonsterDefinition(
                baseName: "Goblin",
                prefix: MonsterAffix(name: "Ancient", type: "prefix", effect: "+50% HP"),
                suffix: MonsterAffix(name: "of Shadows", type: "suffix", effect: "+stealth"),
                hp: 45,
                damage: "2d6+2",
                defense: 14,
                abilities: ["Shadowstep", "Pack Tactics", "Bite"],
                description: "A cunning goblin shrouded in darkness"
            ),
            currentMonsterHP: 30,
            character: CharacterProfile(
                name: "Aragorn",
                race: "Human",
                className: "Warrior",
                backstory: "A skilled fighter",
                attributes: .init(strength: 16, dexterity: 14, constitution: 15, intelligence: 12, wisdom: 13, charisma: 14),
                hp: 25,
                maxHP: 25,
                xp: 150,
                gold: 50,
                inventory: ["Sword", "Shield"],
                abilities: ["Power Strike", "Shield Bash"],
                spells: []
            ),
            detailedInventory: [
                ItemDefinition(
                    baseName: "Healing Potion",
                    prefix: nil,
                    suffix: nil,
                    itemType: "consumable",
                    description: "Restores health",
                    rarity: "common",
                    consumableEffect: "hp",
                    consumableMinValue: 2,
                    consumableMaxValue: 5
                )
            ],
            onAction: { _ in },
            onFlee: {}
        )
    }
}
