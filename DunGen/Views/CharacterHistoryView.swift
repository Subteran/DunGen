import SwiftUI
import SwiftData

struct CharacterHistoryView: View {
    @Query(sort: \DeceasedCharacter.deathDate, order: .reverse) private var deceasedCharacters: [DeceasedCharacter]

    var body: some View {
        Group {
            if deceasedCharacters.isEmpty {
                emptyState
            } else {
                characterList
            }
        }
        .navigationTitle("Fallen Heroes")
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.wave")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No fallen heroes yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Your deceased characters will appear here")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var characterList: some View {
        List {
            ForEach(deceasedCharacters) { character in
                NavigationLink {
                    DeceasedCharacterDetailView(character: character)
                } label: {
                    CharacterHistoryRow(character: character)
                }
            }
        }
    }
}

struct CharacterHistoryRow: View {
    let character: DeceasedCharacter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(character.name)
                    .font(.headline)
                Spacer()
                Text("Level \(character.finalLevel)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(4)
            }

            HStack {
                Text("\(character.race) \(character.className)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(character.deathDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(character.causeOfDeath)
                .font(.caption)
                .foregroundStyle(.red)
                .italic()
        }
        .padding(.vertical, 4)
    }
}

struct DeceasedCharacterDetailView: View {
    let character: DeceasedCharacter

    var formattedPlayTime: String {
        let hours = Int(character.playTime) / 3600
        let minutes = (Int(character.playTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        List {
            Section("Character") {
                LabeledContent("Name", value: character.name)
                LabeledContent("Race", value: character.race)
                LabeledContent("Class", value: character.className)
                LabeledContent("Final Level", value: "\(character.finalLevel)")
            }

            Section("Statistics") {
                LabeledContent("Total XP", value: "\(character.finalXP)")
                LabeledContent("Gold Earned", value: "\(character.finalGold)")
                LabeledContent("Adventures Completed", value: "\(character.adventuresCompleted)")
                LabeledContent("Monsters Defeated", value: "\(character.monstersDefeated)")
                LabeledContent("Items Collected", value: "\(character.itemsCollected)")
                LabeledContent("Time Played", value: formattedPlayTime)
            }

            Section("Demise") {
                LabeledContent("Cause of Death", value: character.causeOfDeath)
                LabeledContent("Date", value: character.deathDate.formatted(date: .long, time: .shortened))
            }
        }
        .navigationTitle(character.name)
    }
}

#Preview {
    NavigationStack {
        CharacterHistoryView()
            .modelContainer(for: DeceasedCharacter.self, inMemory: true)
    }
}
