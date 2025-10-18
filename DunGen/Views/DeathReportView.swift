import SwiftUI

struct DeathReportView: View {
    let report: CharacterDeathReport
    let onNewGame: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "figure.fall")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)

                    Text("Character Fallen")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(report.causeOfDeath)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 32)

                Divider()

                VStack(spacing: 16) {
                    CharacterSummaryRow(
                        label: "Name",
                        value: report.character.name
                    )
                    CharacterSummaryRow(
                        label: "Race",
                        value: report.character.race
                    )
                    CharacterSummaryRow(
                        label: "Class",
                        value: report.character.className
                    )
                    CharacterSummaryRow(
                        label: "Final Level",
                        value: "\(report.finalLevel)"
                    )
                }

                Divider()

                VStack(spacing: 16) {
                    Text("Final Statistics")
                        .font(.headline)

                    StatRow(icon: "star.fill", label: "Total XP", value: "\(report.character.xp)")
                    StatRow(icon: "dollarsign.circle.fill", label: "Gold Earned", value: "\(report.character.gold)")
                    StatRow(icon: "checkmark.circle.fill", label: "Adventures Completed", value: "\(report.adventuresCompleted)")
                    StatRow(icon: "flame.fill", label: "Monsters Defeated", value: "\(report.monstersDefeated)")
                    StatRow(icon: "bag.fill", label: "Items Collected", value: "\(report.itemsCollected)")
                    StatRow(icon: "clock.fill", label: "Time Played", value: report.formattedPlayTime)
                }

                if !report.character.abilities.isEmpty || !report.character.spells.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Skills Mastered")
                            .font(.headline)

                        if !report.character.abilities.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Abilities:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                ForEach(report.character.abilities, id: \.self) { ability in
                                    Text("• \(ability)")
                                        .font(.caption)
                                }
                            }
                        }

                        if !report.character.spells.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Spells:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                ForEach(report.character.spells, id: \.self) { spell in
                                    Text("• \(spell)")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    onNewGame()
                } label: {
                    Text("Start New Adventure")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 16)
            }
            .padding()
        }
        .navigationTitle("Final Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CharacterSummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    NavigationStack {
        DeathReportView(
            report: CharacterDeathReport(
                character: CharacterProfile(
                    name: "Aragorn",
                    race: "Human",
                    className: "Warrior",
                    backstory: "A skilled fighter",
                    attributes: .init(strength: 18, dexterity: 14, constitution: 16, intelligence: 12, wisdom: 13, charisma: 14),
                    hp: 0,
                    maxHP: 20,
                    xp: 450,
                    gold: 275,
                    inventory: ["Flaming Sword", "Steel Armor"],
                    abilities: ["Power Strike", "Shield Bash", "Whirlwind"],
                    spells: []
                ),
                finalLevel: 5,
                adventuresCompleted: 3,
                monstersDefeated: 24,
                itemsCollected: 12,
                causeOfDeath: "Defeated by Ancient Dragon of Flame",
                playTime: 3750
            ),
            onNewGame: {}
        )
    }
}
