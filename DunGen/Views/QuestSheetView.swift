import SwiftUI

struct QuestSheetView: View {
    let progress: AdventureProgress
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Quest")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(progress.questGoal)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(progress.locationName)
                            .font(.body)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Story")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(progress.adventureStory)
                            .font(.body)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("Encounter \(progress.currentEncounter) of \(progress.totalEncounters)")
                                .font(.body)
                            Spacer()
                            ProgressView(value: Double(min(progress.currentEncounter, progress.totalEncounters)), total: Double(progress.totalEncounters))
                                .frame(width: 100)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Quest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
