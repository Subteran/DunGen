import SwiftUI

struct AdventureSummarySheetView: View {
    let summary: AdventureSummary
    let onNextLocation: () async -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quest Completed")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(summary.questGoal)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(summary.completionSummary)
                            .font(.body)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Statistics")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Label("Encounters", systemImage: "map.fill")
                            Spacer()
                            Text("\(summary.encountersCompleted)")
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Label("Monsters Defeated", systemImage: "shield.fill")
                            Spacer()
                            Text("\(summary.monstersDefeated)")
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Label("XP Gained", systemImage: "sparkles")
                            Spacer()
                            Text("\(summary.totalXPGained)")
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Label("Gold Earned", systemImage: "dollarsign.circle.fill")
                            Spacer()
                            Text("\(summary.totalGoldEarned)")
                                .fontWeight(.semibold)
                        }
                    }

                    if !summary.notableItems.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notable Items")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            ForEach(Array(summary.notableItems.enumerated()), id: \.offset) { index, item in
                                HStack {
                                    Image(systemName: "bag.fill")
                                        .foregroundStyle(.blue)
                                    Text(item)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Adventure Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Choose Next Location") {
                        Task {
                            await onNextLocation()
                        }
                    }
                }
            }
        }
    }
}
