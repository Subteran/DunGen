import SwiftUI

struct WorldView: View {
    let worldState: WorldState?

    var body: some View {
        Group {
            if let worldState = worldState {
                worldContent(worldState: worldState)
            } else {
                emptyState
            }
        }
        .navigationTitle("World")
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No world yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start a new game to explore the world")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func worldContent(worldState: WorldState) -> some View {
        List {
            Section {
                Text(worldState.worldStory)
                    .font(.body)
                    .foregroundStyle(.secondary)
            } header: {
                Text("World Story")
            }

            Section {
                ForEach(worldState.locations, id: \.name) { location in
                    NavigationLink {
                        LocationDetailView(location: location)
                    } label: {
                        LocationRow(location: location)
                    }
                }
            } header: {
                Text("Known Locations")
            }
        }
    }
}

struct LocationRow: View {
    let location: WorldLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Location header
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: locationIcon)
                    .font(.title2)
                    .foregroundStyle(locationColor)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.headline)

                    Text(location.locationType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if location.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if location.visited {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(.blue)
                }
            }

            // Quest info in grouped box
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: questIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.questType.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Text(location.questGoal)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }

    private var questIcon: String {
        switch location.questType.lowercased() {
        case "combat": return "crossed.swords"
        case "retrieval": return "cube.box"
        case "escort": return "figure.walk"
        case "investigation": return "magnifyingglass"
        case "rescue": return "hand.raised"
        case "diplomatic": return "bubble.left.and.bubble.right"
        default: return "exclamationmark.circle"
        }
    }

    private var locationIcon: String {
        switch location.locationType {
        case .outdoor: return "tree.fill"
        case .city: return "building.2.fill"
        case .dungeon: return "lock.shield.fill"
        case .village: return "house.fill"
        }
    }

    private var locationColor: Color {
        switch location.locationType {
        case .outdoor: return .green
        case .city: return .blue
        case .dungeon: return .purple
        case .village: return .orange
        }
    }
}

struct LocationDetailView: View {
    let location: WorldLocation

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: locationIcon)
                        .font(.largeTitle)
                        .foregroundStyle(locationColor)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(location.locationType.rawValue)
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        if location.completed {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if location.visited {
                            Label("Visited", systemImage: "eye.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } else {
                            Label("Undiscovered", systemImage: "questionmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Text(location.description)
                    .font(.body)
            } header: {
                Text("Description")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quest Type:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(location.questType.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text(location.questGoal)
                        .font(.body)
                }
            } header: {
                Text("Quest")
            }
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var locationIcon: String {
        switch location.locationType {
        case .outdoor: return "tree.fill"
        case .city: return "building.2.fill"
        case .dungeon: return "lock.shield.fill"
        case .village: return "house.fill"
        }
    }

    private var locationColor: Color {
        switch location.locationType {
        case .outdoor: return .green
        case .city: return .blue
        case .dungeon: return .purple
        case .village: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        WorldView(worldState: WorldState(
            worldStory: "The kingdom of Eldoria has fallen into darkness. Ancient evils stir in forgotten places, and heroes are needed to restore the light.",
            locations: [
                WorldLocation(
                    name: "Whispering Woods",
                    locationType: .outdoor,
                    description: "A dense forest where strange sounds echo through the trees. Local villagers speak of bandits and worse lurking in the shadows.",
                    questType: "combat",
                    questGoal: "Defeat the bandit leader terrorizing the woods",
                    visited: true,
                    completed: false
                ),
                WorldLocation(
                    name: "Ironhaven",
                    locationType: .city,
                    description: "The grand capital city, home to thousands. Markets bustle with trade, but rumors of corruption spread through the noble courts.",
                    questType: "investigation",
                    questGoal: "Investigate the corruption in the noble courts",
                    visited: false,
                    completed: false
                ),
                WorldLocation(
                    name: "Blackstone Ruins",
                    locationType: .dungeon,
                    description: "Ancient crypts beneath a fallen fortress. Undead creatures guard forgotten treasures and terrible secrets.",
                    questType: "retrieval",
                    questGoal: "Retrieve the ancient artifact from the ruins",
                    visited: false,
                    completed: false
                )
            ]
        ))
    }
}

#Preview("Empty State") {
    NavigationStack {
        WorldView(worldState: nil)
    }
}
