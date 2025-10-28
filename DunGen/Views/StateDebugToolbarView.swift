import SwiftUI
import MessageUI
import FoundationModels

struct StateDebugToolbarView: View {
    let viewModel: GameViewModel
    let levelingService: LevelingServiceProtocol
    @Binding var showMailComposer: Bool
    @Binding var emailWithStateAttachment: Bool

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
                emailWithStateAttachment = true
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
                emailWithStateAttachment = true
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

        text += "\n📝 COMPLETE NARRATIVE LOG (\(viewModel.log.count) entries):\n"
        for (index, entry) in viewModel.log.enumerated() {
            let prefix = entry.isFromModel ? "[MODEL]" : "[PLAYER]"
            text += "\(index + 1). \(prefix) \(entry.content)\n"
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

        text += "\n📜 LLM TRANSCRIPTS:\n"
        for specialist in LLMSpecialist.allCases {
            if let transcript = viewModel.engine.sessionManager.getTranscript(for: specialist) {
                let entries = Array(transcript)
                text += "\n[\(specialist.rawValue.uppercased())] - \(entries.count) entries:\n"
                for (index, entry) in entries.enumerated() {
                    text += formatTranscriptEntry(entry, index: index + 1)
                }
            }
        }

        text += "\n========== END DUMP ==========\n"
        return text
    }

    private func dumpAdventureState() {
        print("\n" + buildAdventureStateText())
    }

    private func formatTranscriptEntry(_ entry: Transcript.Entry, index: Int) -> String {
        if case .prompt(let prompt) = entry {
            let promptText = String(describing: prompt)
            return "  \(index). PROMPT (\(promptText.count) chars): \(promptText.prefix(100))...\n"
        } else if case .response(let response) = entry {
            let responseText = String(describing: response)
            return "  \(index). RESPONSE (\(responseText.count) chars): \(responseText.prefix(100))...\n"
        }
        return ""
    }
}
