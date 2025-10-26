import SwiftUI

struct LogEntryView: View {
    let entry: GameLogEntry
    let width: CGFloat
    let isLocationEntry: Bool
    let isTappable: Bool
    let onLocationTap: ((String) -> Void)?

    init(entry: GameLogEntry, width: CGFloat, awaitingLocationSelection: Bool, onLocationTap: ((String) -> Void)?) {
        self.entry = entry
        self.width = width
        self.isLocationEntry = entry.content.hasPrefix("• ")
        self.isTappable = isLocationEntry && awaitingLocationSelection
        self.onLocationTap = onLocationTap
    }

    var body: some View {
        Group {
            if entry.showCharacterSprite, let character = entry.characterForSprite {
                characterSpriteView(character: character)
            } else if entry.showMonsterSprite, let monster = entry.monsterForSprite {
                monsterSpriteView(monster: monster)
            } else if isTappable {
                tappableLocationView
            } else {
                standardTextView
            }
        }
    }

    private func characterSpriteView(character: CharacterProfile) -> some View {
        VStack(spacing: 12) {
            Text(entry.content)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            PaperDollView(
                character: character,
                detailedInventory: [],
                size: width * 0.75
            )
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .id(entry.id)
    }

    private func monsterSpriteView(monster: MonsterDefinition) -> some View {
        VStack(spacing: 12) {
            MonsterSprite.spriteView(
                monsterName: monster.baseName,
                size: width * 0.75
            )
            .frame(maxWidth: .infinity, alignment: .center)

            Text(entry.content)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .id(entry.id)
    }

    private var tappableLocationView: some View {
        Button {
            if let locationName = extractLocationName(from: entry.content) {
                onLocationTap?(locationName)
            }
        } label: {
            Text(entry.content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.blue.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .id(entry.id)
    }

    private var standardTextView: some View {
        Text(entry.content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(entry.isFromModel ? Color.secondary.opacity(0.1) : Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .id(entry.id)
    }

    private func extractLocationName(from text: String) -> String? {
        guard text.hasPrefix("• ") else { return nil }
        let withoutBullet = text.dropFirst(2)
        if let parenIndex = withoutBullet.firstIndex(of: "(") {
            return String(withoutBullet[..<parenIndex]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}
