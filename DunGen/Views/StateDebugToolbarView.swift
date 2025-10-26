import SwiftUI
import MessageUI

struct StateDebugToolbarView: View {
    let viewModel: GameViewModel
    let levelingService: LevelingServiceProtocol
    @Binding var showMailComposer: Bool

    var body: some View {
        HStack {
            #if DEBUG
            Button {
                dumpAdventureState()
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Dump State")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.orange)

            Button {
                showMailComposer = true
            } label: {
                HStack {
                    Image(systemName: "envelope")
                    Text("Email State")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            #else
            Button {
                showMailComposer = true
            } label: {
                HStack {
                    Image(systemName: "envelope")
                    Text("Email State")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            #endif

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
    }

    private func buildAdventureStateText() -> String {
        var text = "========== ADVENTURE STATE DUMP ==========\n\n"

        // Lifetime Statistics
        text += "📊 LIFETIME STATISTICS:\n"
        text += "Adventures Completed: \(viewModel.adventuresCompleted)\n"
        text += "Total Monsters Defeated: \(viewModel.totalMonstersDefeated)\n"
        text += "Total XP Earned: \(viewModel.totalXPEarned)\n"
        text += "Total Gold Earned: \(viewModel.totalGoldEarned)\n"
        text += "Items Collected: \(viewModel.itemsCollected)\n"
        if let startTime = viewModel.gameStartTime {
            let playTime = Date().timeIntervalSince(startTime)
            let hours = Int(playTime) / 3600
            let minutes = (Int(playTime) % 3600) / 60
            text += "Play Time: \(hours)h \(minutes)m\n"
        }

        if let char = viewModel.character {
            let level = levelingService.level(forXP: char.xp)
            text += "\n📜 CHARACTER:\n"
            text += "Name: \(char.name)\n"
            text += "Race: \(char.race) | Class: \(char.className)\n"
            text += "Level: \(level) | XP: \(char.xp)\n"
            text += "HP: \(char.hp)/\(char.maxHP)\n"
            text += "Gold: \(char.gold)\n"
        }

        if let progress = viewModel.adventureProgress {
            text += "\n🎯 ADVENTURE PROGRESS:\n"
            text += "Location: \(progress.locationName)\n"
            text += "Quest: \(progress.questGoal)\n"
            text += "Story: \(progress.adventureStory)\n"
            text += "Progress: \(progress.currentEncounter)/\(progress.totalEncounters)\n"
            text += "Completed: \(progress.completed)\n"

            text += "\n📖 ENCOUNTER SUMMARIES:\n"
            for (index, summary) in progress.encounterSummaries.enumerated() {
                text += "\(index + 1). \(summary)\n"
            }
        }

        text += "\n📝 NARRATIVE LOG (last 10 entries):\n"
        for entry in viewModel.log.suffix(10) {
            let prefix = entry.isFromModel ? "[MODEL]" : "[PLAYER]"
            text += "\(prefix) \(entry.content)\n"
        }

        if let monster = viewModel.currentMonster {
            text += "\n⚔️ CURRENT MONSTER:\n"
            text += "Name: \(monster.fullName)\n"
            text += "HP: \(viewModel.currentMonsterHP)/\(monster.hp)\n"
            text += "In Combat: \(viewModel.inCombat)\n"
        }

        if let transaction = viewModel.pendingTransaction {
            text += "\n💰 PENDING TRANSACTION:\n"
            text += "Items: \(transaction.items.joined(separator: ", "))\n"
            text += "Cost: \(transaction.cost) gold\n"
        }

        text += "\n========== END DUMP ==========\n"
        return text
    }

    private func dumpAdventureState() {
        print("\n" + buildAdventureStateText())
    }
}
