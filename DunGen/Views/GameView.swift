import SwiftUI
import SwiftData
import MessageUI
import OSLog

struct GameView: View {
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "GameView")
    @State private var viewModel: GameViewModel
    @State private var input: String = ""
    @State private var showNewGameConfirmation = false
    @State private var showCustomInputSheet = false
    @State private var showDeathReport = false
    @State private var showActionsSheet = false
    @State private var showQuestSheet = false
    @State private var showMailComposer = false
    @State private var emailWithStateAttachment = false
    @FocusState private var inputFocused: Bool
    @Environment(\.modelContext) private var modelContext

    nonisolated init(viewModel: GameViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var combatMonsterBinding: Binding<MonsterDefinition?> {
        Binding(
            get: { viewModel.inCombat && viewModel.currentMonster != nil && viewModel.character != nil ? viewModel.currentMonster : nil },
            set: { _ in }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            mainContent(geometry: geometry)
        }
        .overlay { loadingOverlay }
        .navigationTitle(L10n.tabGameTitle)
        .toolbar { toolbar }
        .task { await startIfAvailable() }
        .confirmationDialog(
            L10n.newGameConfirmTitle,
            isPresented: $showNewGameConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.newGameConfirmDelete, role: .destructive) {
                Task {
                    let usedNames = getUsedCharacterNames()
                    await viewModel.startNewGame(preferredType: viewModel.currentLocation, usedNames: usedNames)
                }
            }
            Button(L10n.newGameConfirmCancel, role: .cancel) {}
        } message: {
            Text(L10n.newGameConfirmMessage)
        }
        .sheet(isPresented: $showCustomInputSheet) {
            CustomInputSheet(input: $input, onSubmit: {
                submitCustomInput()
                showCustomInputSheet = false
            }, onCancel: {
                input = ""
                showCustomInputSheet = false
            })
        }
        .fullScreenCover(item: combatMonsterBinding) { monster in
            combatView(for: monster)
        }
        .fullScreenCover(isPresented: $showDeathReport) {
            deathReportView
        }
        .onChange(of: viewModel.characterDied) { _, died in
            if died {
                showDeathReport = true
            }
        }
        .onChange(of: viewModel.needsInventoryManagement) { _, newValue in
            viewModel.showingInventoryManagement = newValue
        }
        .sheet(isPresented: $viewModel.showingInventoryManagement) {
            InventoryManagementView(
                currentInventory: viewModel.detailedInventory,
                newItems: viewModel.pendingLoot,
                maxSlots: 20,
                onConfirm: { selectedItems in
                    viewModel.finalizeInventorySelection(selectedItems)
                }
            )
        }
        .sheet(isPresented: $showActionsSheet) {
            ActionsSheetView(
                suggestedActions: viewModel.suggestedActions,
                showCustomInputSheet: $showCustomInputSheet,
                isPresented: $showActionsSheet,
                onActionSelected: submitAction
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
        }
        .sheet(isPresented: $showQuestSheet) {
            if let progress = viewModel.adventureProgress {
                QuestSheetView(progress: progress, isPresented: $showQuestSheet)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled)
            }
        }
        .sheet(isPresented: $viewModel.showingAdventureSummary) {
            if let summary = viewModel.adventureSummary {
                let _ = logger.info("[GameView] Presenting AdventureSummarySheet with summary: \(summary.questGoal)")
                AdventureSummarySheetView(
                    summary: summary,
                    onNextLocation: {
                        viewModel.showingAdventureSummary = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(100))
                            await viewModel.promptForNextLocation()
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            } else {
                let _ = logger.warning("[GameView] Sheet presented but adventureSummary is NIL!")
                Text("No summary available")
                    .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $showMailComposer) {
            if MFMailComposeViewController.canSendMail() {
                let stateURL = emailWithStateAttachment ? getGameStateURL() : nil
                let subject = emailWithStateAttachment ? "DunGen Debug - Game State" : "DunGen Feedback"
                let body = emailWithStateAttachment ? "Game state JSON attached.\n\n" : ""

                MailComposeView(
                    subject: subject,
                    messageBody: body,
                    isPresented: $showMailComposer,
                    attachmentURL: stateURL
                )
            }
        }
        .onChange(of: showMailComposer) { _, newValue in
            if !newValue {
                emailWithStateAttachment = false
            }
        }
    }

    @ViewBuilder
    private func mainContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            stateToolbar
            Divider()

            if viewModel.character != nil {
                header
                Divider()
            }

            ScrollViewReader { proxy in
                ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.log) { entry in
                                LogEntryView(
                                    entry: entry,
                                    width: geometry.size.width,
                                    awaitingLocationSelection: viewModel.awaitingLocationSelection,
                                    onLocationTap: { locationName in
                                        Task {
                                            await viewModel.submitPlayer(input: locationName)
                                        }
                                    }
                                )
                            }

                        GameStateButtonsView(
                            viewModel: viewModel,
                            showDeathReport: $showDeathReport,
                            showActionsSheet: $showActionsSheet,
                            onContinue: {
                                let usedNames = getUsedCharacterNames()
                                await viewModel.continueNewGame(usedNames: usedNames)
                            }
                        )
                    }
                    .padding(12)
                }
                .onChange(of: viewModel.log) { _, newValue in
                    if let last = newValue.last?.id {
                        withAnimation {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }


    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isGenerating {
            LoadingOverlayView()
        }
    }

    @ViewBuilder
    private func combatView(for monster: MonsterDefinition) -> some View {
            if let character = viewModel.character {
                NavigationStack {
                    CombatView(
                        monster: monster,
                        currentMonsterHP: viewModel.currentMonsterHP,
                        character: character,
                        detailedInventory: viewModel.detailedInventory,
                        onAction: { action in
                            Task {
                                await handleCombatAction(action)
                            }
                        },
                        onFlee: {
                            let _ = viewModel.fleeCombat()
                        }
                    )
                    .background(Color(UIColor.systemBackground))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                viewModel.combatManager.inCombat = false
                            }
                        }
                    }
                }
            }
    }

    // MARK: - Subviews
    private var header: some View {
        VStack(spacing: 0) {
            if let character = viewModel.character {
                characterStatusBar(character)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func characterStatusBar(_ character: CharacterProfile) -> some View {
        HStack(spacing: 12) {
            StatusBadge(
                label: L10n.characterLabelLevel,
                value: "\(levelingService.level(forXP: character.xp))",
                icon: "star.fill"
            )
            StatusBadge(
                label: L10n.characterLabelHp,
                value: "\(character.hp)/\(character.maxHP)",
                icon: "heart.fill"
            )
            StatusBadge(
                label: L10n.characterLabelXp,
                value: "\(character.xp)",
                icon: "sparkles"
            )
            StatusBadge(
                label: L10n.characterLabelGold,
                value: "\(character.gold)",
                icon: "dollarsign.circle.fill"
            )
        }
        .font(.caption)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var levelingService: LevelingServiceProtocol {
        DefaultLevelingService()
    }




    @ViewBuilder
    private var deathReportView: some View {
        if let report = viewModel.deathReport {
            NavigationStack {
                DeathReportView(
                    report: report,
                    onNewGame: {
                        let deceased = report.toDeceasedCharacter(levelingService: levelingService)
                        modelContext.insert(deceased)
                        showDeathReport = false
                        Task {
                            let usedNames = getUsedCharacterNames()
                            await viewModel.startNewGame(preferredType: viewModel.currentLocation, usedNames: usedNames)
                        }
                    },
                    engine: viewModel.engine
                )
                .background(Color(UIColor.systemBackground))
            }
        }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if viewModel.character != nil, viewModel.adventureProgress != nil, !viewModel.awaitingWorldContinue {
                Button {
                    showQuestSheet = true
                } label: {
                    Label("Quest", systemImage: "scroll")
                }
            }

            Button {
                if viewModel.character != nil {
                    showNewGameConfirmation = true
                } else {
                    Task {
                        let usedNames = getUsedCharacterNames()
                        await viewModel.startNewGame(preferredType: viewModel.currentLocation, usedNames: usedNames)
                    }
                }
            } label: {
                Label(L10n.newGame, systemImage: "gamecontroller")
            }
        }
    }

    // MARK: - State Sharing
    @ViewBuilder
    private var stateToolbar: some View {
        StateDebugToolbarView(
            viewModel: viewModel,
            levelingService: levelingService,
            showMailComposer: $showMailComposer,
            emailWithStateAttachment: $emailWithStateAttachment
        )
    }

    private func getGameStateURL() -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("gameState.json")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }


    // MARK: - Actions
    private func submitAction(_ action: String) {
        Task {
            await viewModel.submitPlayer(input: action)
        }
    }

    private func submitCustomInput() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            await viewModel.submitPlayer(input: text)
        }
        input = ""
    }

    private func startIfAvailable() async {
        if case .available = viewModel.availability {
            if viewModel.character == nil || viewModel.characterDied {
                let usedNames = getUsedCharacterNames()
                await viewModel.startNewGame(preferredType: viewModel.currentLocation, usedNames: usedNames)
            }
            // NOTE: Removed auto-continue logic - it was causing unwanted auto-advance on app resume
            // If suggestedActions is empty after load, the player should manually advance
        }
    }

    private func getUsedCharacterNames() -> [String] {
        let descriptor = FetchDescriptor<DeceasedCharacter>()
        let deceasedCharacters = (try? modelContext.fetch(descriptor)) ?? []
        return deceasedCharacters.map { $0.name }
    }


    private func handleCombatAction(_ action: CombatView.CombatAction) async {
        switch action {
        case .attack:
            await viewModel.performCombatAction("attack")
        case .useAbility(let ability):
            await viewModel.performCombatAction("use ability: \(ability)")
        case .useSpell(let spell):
            await viewModel.performCombatAction("cast spell: \(spell)")
        case .usePrayer(let prayer):
            await viewModel.performCombatAction("pray: \(prayer)")
        case .useItem(let itemName):
            let success = viewModel.useItem(itemName: itemName)
            if success {
                await viewModel.performCombatAction("used item")
            }
        case .flee:
            let _ = viewModel.fleeCombat()
        case .surrender:
            viewModel.surrenderCombat()
        }
    }
}

#Preview {
    NavigationStack {
        GameView(viewModel: GameViewModel()).task {
        }
    }
}
