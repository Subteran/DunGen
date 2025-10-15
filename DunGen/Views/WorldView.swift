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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: locationIcon)
                .font(.title2)
                .foregroundStyle(locationColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
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
        .padding(.vertical, 4)
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
                    visited: true,
                    completed: false
                ),
                WorldLocation(
                    name: "Ironhaven",
                    locationType: .city,
                    description: "The grand capital city, home to thousands. Markets bustle with trade, but rumors of corruption spread through the noble courts.",
                    visited: false,
                    completed: false
                ),
                WorldLocation(
                    name: "Blackstone Ruins",
                    locationType: .dungeon,
                    description: "Ancient crypts beneath a fallen fortress. Undead creatures guard forgotten treasures and terrible secrets.",
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
