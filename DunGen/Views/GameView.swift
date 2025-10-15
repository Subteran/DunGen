import SwiftUI
import SwiftData

struct GameView: View {
    @State private var engine: LLMGameEngine
    @State private var input: String = ""
    @State private var showNewGameConfirmation = false
    @State private var showCustomInputSheet = false
    @State private var showCombatView = false
    @State private var showDeathReport = false
    @State private var showActionsSheet = false
    @State private var showQuestSheet = false
    @State private var showInventoryManagement = false
    @FocusState private var inputFocused: Bool
    @Environment(\.modelContext) private var modelContext

    nonisolated init(engine: LLMGameEngine? = nil) {
        _engine = State(initialValue: engine ?? LLMGameEngine(levelingService: DefaultLevelingService()))
    }

    var body: some View {
        VStack(spacing: 0) {
            if engine.character != nil {
                header
                Divider()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(engine.log) { entry in
                            Text(entry.content)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(entry.isFromModel ? Color.secondary.opacity(0.1) : Color.accentColor.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .id(entry.id)
                        }

                        if !engine.suggestedActions.isEmpty {
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
                    .padding(12)
                }
                .onChange(of: engine.log) { _, newValue in
                    if let last = newValue.last?.id {
                        withAnimation {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .overlay {
            if engine.isGenerating {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        Text("creating...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
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
                    await engine.startNewGame(preferredType: engine.currentLocation, usedNames: usedNames)
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
        .fullScreenCover(isPresented: $showCombatView) {
            if let monster = engine.currentMonster, let character = engine.character {
                NavigationStack {
                    CombatView(
                        monster: monster,
                        character: character,
                        onAction: { action in
                            Task {
                                await handleCombatAction(action)
                            }
                        },
                        onFlee: {
                            Task {
                                await engine.fleeCombat()
                                showCombatView = false
                            }
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showCombatView = false
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showDeathReport) {
            if let report = engine.deathReport {
                NavigationStack {
                    DeathReportView(
                        report: report,
                        onNewGame: {
                            let deceased = report.toDeceasedCharacter(levelingService: levelingService)
                            modelContext.insert(deceased)
                            showDeathReport = false
                            Task {
                                let usedNames = getUsedCharacterNames()
                                await engine.startNewGame(preferredType: engine.currentLocation, usedNames: usedNames)
                            }
                        }
                    )
                }
            }
        }
        .onChange(of: engine.inCombat) { _, newValue in
            showCombatView = newValue
        }
        .onChange(of: engine.characterDied) { _, newValue in
            if newValue {
                showCombatView = false
                showDeathReport = true
            }
        }
        .onChange(of: engine.needsInventoryManagement) { _, newValue in
            showInventoryManagement = newValue
        }
        .sheet(isPresented: $showInventoryManagement) {
            InventoryManagementView(
                currentInventory: engine.detailedInventory,
                newItems: engine.pendingLoot,
                maxSlots: 20,
                onConfirm: { selectedItems in
                    engine.finalizeInventorySelection(selectedItems)
                }
            )
        }
        .sheet(isPresented: $showActionsSheet) {
            actionsSheet
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
        }
        .sheet(isPresented: $showQuestSheet) {
            if let progress = engine.adventureProgress {
                questSheet(progress: progress)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Subviews
    private var header: some View {
        VStack(spacing: 0) {
            if let character = engine.character {
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
                value: "\(character.hp)",
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

    private var actionsSheet: some View {
        VStack(spacing: 12) {
            Text("Choose Your Action")
                .font(.headline)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(engine.suggestedActions.enumerated()), id: \.offset) { index, action in
                        Button {
                            submitAction(action)
                            showActionsSheet = false
                        } label: {
                            Text(action)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        showCustomInputSheet = true
                        showActionsSheet = false
                    } label: {
                        HStack {
                            Text(L10n.actionOr)
                                .foregroundStyle(.secondary)
                            Text(L10n.actionCustom)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func questSheet(progress: AdventureProgress) -> some View {
        NavigationStack {
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
                        ProgressView(value: Double(progress.currentEncounter), total: Double(progress.totalEncounters))
                            .frame(width: 100)
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Quest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showQuestSheet = false
                    }
                }
            }
        }
    }


    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if engine.character != nil, let progress = engine.adventureProgress {
                Button {
                    showQuestSheet = true
                } label: {
                    Label("Quest", systemImage: "scroll")
                }
            }

            Button {
                if engine.character != nil {
                    showNewGameConfirmation = true
                } else {
                    Task {
                        let usedNames = getUsedCharacterNames()
                        await engine.startNewGame(preferredType: engine.currentLocation, usedNames: usedNames)
                    }
                }
            } label: {
                Label(L10n.newGame, systemImage: "gamecontroller")
            }
        }
    }

    // MARK: - Actions
    private func submitAction(_ action: String) {
        Task {
            await engine.submitPlayer(input: action)
        }
    }

    private func submitCustomInput() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            await engine.submitPlayer(input: text)
        }
        input = ""
    }

    private func startIfAvailable() async {
        engine.checkAvailabilityAndConfigure()
        engine.loadState()

        if case .available = engine.availability, engine.character == nil {
            let usedNames = getUsedCharacterNames()
            await engine.startNewGame(preferredType: engine.currentLocation, usedNames: usedNames)
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
            await engine.performCombatAction("attack")
        case .useAbility(let ability):
            await engine.performCombatAction("use ability: \(ability)")
        case .useSpell(let spell):
            await engine.performCombatAction("cast spell: \(spell)")
        case .usePrayer(let prayer):
            await engine.performCombatAction("pray: \(prayer)")
        case .flee:
            let _ = await engine.fleeCombat()
            showCombatView = false
        case .surrender:
            await engine.surrenderCombat()
            showCombatView = false
        }

        if !engine.inCombat {
            showCombatView = false
        }
    }
}

struct StatusBadge: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
    }
}

struct CustomInputSheet: View {
    @Binding var input: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField(L10n.inputPlaceholder, text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...10)
                    .focused($isFocused)
                    .padding()

                Spacer()
            }
            .navigationTitle(L10n.actionCustom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.newGameConfirmCancel) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSubmit()
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        GameView().task {
        }
    }
}
