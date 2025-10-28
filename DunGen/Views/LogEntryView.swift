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
            if let locationInfo = parseLocationInfo(from: entry.content) {
                VStack(alignment: .leading, spacing: 8) {
                    // Location header
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: locationIcon(for: locationInfo.locationType))
                            .font(.title2)
                            .foregroundStyle(locationColor(for: locationInfo.locationType))
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(locationInfo.name)
                                .font(.headline)

                            Text(locationInfo.locationType)
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.85))
                        }

                        Spacer()
                    }

                    // Location description
                    Text(locationInfo.description)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(2)

                    // Quest info in grouped box
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: questIcon(for: locationInfo.questType))
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.6))
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(locationInfo.questType.capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary.opacity(0.85))

                            Text(locationInfo.questGoal)
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.85))
                                .lineLimit(2)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(6)
                }
                .padding(12)
                .background(Color.blue.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(entry.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
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
        if let pipeIndex = withoutBullet.firstIndex(of: "|") {
            return String(withoutBullet[..<pipeIndex]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private struct LocationInfo {
        let name: String
        let locationType: String
        let questType: String
        let questGoal: String
        let description: String
    }

    private func parseLocationInfo(from text: String) -> LocationInfo? {
        guard text.hasPrefix("• ") else { return nil }
        let withoutBullet = String(text.dropFirst(2))
        let components = withoutBullet.components(separatedBy: "|")
        guard components.count == 5 else { return nil }
        return LocationInfo(
            name: components[0].trimmingCharacters(in: .whitespaces),
            locationType: components[1].trimmingCharacters(in: .whitespaces),
            questType: components[2].trimmingCharacters(in: .whitespaces),
            questGoal: components[3].trimmingCharacters(in: .whitespaces),
            description: components[4].trimmingCharacters(in: .whitespaces)
        )
    }

    private func locationIcon(for locationType: String) -> String {
        switch locationType.lowercased() {
        case "outdoor": return "tree.fill"
        case "city": return "building.2.fill"
        case "dungeon": return "lock.shield.fill"
        case "village": return "house.fill"
        default: return "mappin"
        }
    }

    private func locationColor(for locationType: String) -> Color {
        switch locationType.lowercased() {
        case "outdoor": return .green
        case "city": return .blue
        case "dungeon": return .purple
        case "village": return .orange
        default: return .gray
        }
    }

    private func questIcon(for questType: String) -> String {
        switch questType.lowercased() {
        case "combat": return "flame.fill"
        case "retrieval": return "cube.box"
        case "escort": return "figure.walk"
        case "investigation": return "magnifyingglass"
        case "rescue": return "hand.raised"
        case "diplomatic": return "bubble.left.and.bubble.right"
        default: return "exclamationmark.circle"
        }
    }
}
