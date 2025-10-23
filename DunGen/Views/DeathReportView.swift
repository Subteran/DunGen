import SwiftUI
import MessageUI

struct DeathReportView: View {
    let report: CharacterDeathReport
    let onNewGame: () -> Void
    let engine: LLMGameEngine?
    @State private var showMailComposer = false

    init(report: CharacterDeathReport, onNewGame: @escaping () -> Void, engine: LLMGameEngine? = nil) {
        self.report = report
        self.onNewGame = onNewGame
        self.engine = engine
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        PaperDollView(
                            character: report.character,
                            detailedInventory: [],
                            size: geometry.size.width * 0.75
                        )
                        .opacity(0.6)
                        .grayscale(0.8)

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

                if let engine = engine {
                    Button {
                        #if DEBUG
                        dumpAdventureState(engine: engine)
                        #else
                        showMailComposer = true
                        #endif
                    } label: {
                        HStack {
                            #if DEBUG
                            Image(systemName: "ant.circle")
                            Text("Dump State to Console")
                            #else
                            Image(systemName: "envelope")
                            Text("Email Death Report")
                            #endif
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
            }
            .navigationTitle("Final Report")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showMailComposer) {
                if MFMailComposeViewController.canSendMail() {
                    MailComposeView(
                        subject: "DunGen Death Report",
                        messageBody: buildDeathReportText(),
                        isPresented: $showMailComposer
                    )
                }
            }
        }
    }

    private func buildDeathReportText() -> String {
        var text = "========== DEATH REPORT ==========\n\n"

        let level = DefaultLevelingService().level(forXP: report.character.xp)
        text += "📜 DECEASED CHARACTER:\n"
        text += "Name: \(report.character.name)\n"
        text += "Race: \(report.character.race) | Class: \(report.character.className)\n"
        text += "Final Level: \(level)\n"
        text += "XP: \(report.character.xp)\n"
        text += "Gold: \(report.character.gold)\n"
        text += "Cause of Death: \(report.causeOfDeath)\n\n"

        text += "📊 FINAL STATISTICS:\n"
        text += "Adventures Completed: \(report.adventuresCompleted)\n"
        text += "Monsters Defeated: \(report.monstersDefeated)\n"
        text += "Items Collected: \(report.itemsCollected)\n"
        text += "Time Played: \(report.formattedPlayTime)\n\n"

        if let engine = engine {
            if let progress = engine.adventureProgress {
                text += "🎯 ADVENTURE PROGRESS AT DEATH:\n"
                text += "Location: \(progress.locationName)\n"
                text += "Quest: \(progress.questGoal)\n"
                text += "Progress: \(progress.currentEncounter)/\(progress.totalEncounters)\n"
                text += "Completed: \(progress.completed)\n\n"
            }

            text += "📝 NARRATIVE LOG (last 10 entries):\n"
            for entry in engine.log.suffix(10) {
                let prefix = entry.isFromModel ? "[MODEL]" : "[PLAYER]"
                text += "\(prefix) \(entry.content)\n"
            }
        }

        text += "\n========== END REPORT ==========\n"
        return text
    }

    #if DEBUG
    private func dumpAdventureState(engine: LLMGameEngine) {
        var text = "========== DEATH STATE DUMP ==========\n\n"

        let level = DefaultLevelingService().level(forXP: report.character.xp)
        text += "📜 DECEASED CHARACTER:\n"
        text += "Name: \(report.character.name)\n"
        text += "Race: \(report.character.race) | Class: \(report.character.className)\n"
        text += "Final Level: \(level)\n"
        text += "XP: \(report.character.xp)\n"
        text += "Gold: \(report.character.gold)\n"
        text += "Cause of Death: \(report.causeOfDeath)\n"
        text += "Adventures Completed: \(report.adventuresCompleted)\n"
        text += "Monsters Defeated: \(report.monstersDefeated)\n"
        text += "Items Collected: \(report.itemsCollected)\n"

        if let progress = engine.adventureProgress {
            text += "\n🎯 ADVENTURE PROGRESS AT DEATH:\n"
            text += "Location: \(progress.locationName)\n"
            text += "Quest: \(progress.questGoal)\n"
            text += "Progress: \(progress.currentEncounter)/\(progress.totalEncounters)\n"
            text += "Completed: \(progress.completed)\n"
        }

        text += "\n📝 NARRATIVE LOG (last 10 entries):\n"
        for entry in engine.log.suffix(10) {
            let prefix = entry.isFromModel ? "[MODEL]" : "[PLAYER]"
            text += "\(prefix) \(entry.content)\n"
        }

        text += "\n========== END DUMP ==========\n"
        print("\n" + text)
    }
    #endif
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
