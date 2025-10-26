//
//  ContentView.swift
//  DunGen
//
//  Created by William Wright on 10/13/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = GameViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                GameView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            availabilityBadge
                        }
                    }
            }
            .tabItem {
                Label(L10n.tabGameTitle, systemImage: "wand.and.stars")
            }

            NavigationStack {
                CharacterView(
                    character: viewModel.character,
                    detailedInventory: viewModel.detailedInventory,
                    onUseItem: { itemName in
                        return viewModel.useItem(itemName: itemName)
                    }
                )
            }
            .tabItem {
                Label(L10n.tabCharacterTitle, systemImage: "person.fill")
            }

            NavigationStack {
                WorldView(worldState: viewModel.worldState)
            }
            .tabItem {
                Label("World", systemImage: "map.fill")
            }

            NavigationStack {
                CharacterHistoryView()
            }
            .tabItem {
                Label("History", systemImage: "book.fill")
            }

        }
    }

    @ViewBuilder
    private var availabilityBadge: some View {
        switch viewModel.availability {
        case .available:
            Label(L10n.onDevice, systemImage: "bolt.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .unavailable(let reason):
            Label(String(format: L10n.onDeviceUnavailableFormat, reason), systemImage: "bolt.slash")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: DeceasedCharacter.self, inMemory: true)
}
