import SwiftUI
import SwiftData

struct GameStateButtonsView: View {
    let viewModel: GameViewModel
    @Binding var showDeathReport: Bool
    @Binding var showActionsSheet: Bool
    let onContinue: () async -> Void

    var body: some View {
        Group {
            if viewModel.awaitingWorldContinue, viewModel.character != nil {
                continueButton
            } else if viewModel.characterDied {
                deathStateView
            } else if viewModel.adventureSummary != nil {
                adventureCompleteView
            } else if !viewModel.suggestedActions.isEmpty {
                actionsButton
            }
        }
    }

    private var continueButton: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    await onContinue()
                }
            } label: {
                HStack {
                    Text("Continue")
                    Image(systemName: "arrow.right.circle.fill")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 8)
    }

    private var deathStateView: some View {
        VStack(spacing: 16) {
            Text("💀 Your Character Has Fallen")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.red)

            if let report = viewModel.deathReport {
                Text(report.causeOfDeath)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button {
                showDeathReport = true
            } label: {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("View Death Report")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.top, 16)
    }

    private var adventureCompleteView: some View {
        VStack(spacing: 16) {
            Text("🎉 Quest Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.green)

            Button {
                viewModel.showingAdventureSummary = true
            } label: {
                HStack {
                    Image(systemName: "chart.bar.fill")
                    Text("View Adventure Summary")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.top, 16)
    }

    private var actionsButton: some View {
        Button {
            showActionsSheet = true
        } label: {
            HStack {
                Image(systemName: "list.bullet")
                Text("Actions")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 8)
    }
}
