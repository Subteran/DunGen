import SwiftUI
import SwiftData
import MessageUI

struct GameView: View {
    @State private var engine: any GameEngine
    @State private var input: String = ""
    @State private var showNewGameConfirmation = false
    @State private var showCustomInputSheet = false
    @State private var showDeathReport = false
    @State private var showActionsSheet = false
    @State private var showQuestSheet = false
    @State private var showInventoryManagement = false
    @State private var showAdventureSummarySheet = false
    @State private var showMailComposer = false
    @FocusState private var inputFocused: Bool
    @Environment(\.modelContext) private var modelContext

    nonisolated init(engine: (any GameEngine)? = nil) {
        _engine = State(initialValue: engine ?? LLMGameEngine(levelingService: DefaultLevelingService()))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                stateToolbar
                Divider()

                if engine.character != nil {
                    header
                    Divider()
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(engine.log) { entry in
                                if entry.showCharacterSprite, let character = entry.characterForSprite {
                                    VStack(spacing: 12) {
                                        Text(entry.content)
                                            .font(.headline)
                                            .frame(maxWidth: .infinity, alignment: .center)

                                        PaperDollView(
                                            character: character,
                                            detailedInventory: [],
                                            size: geometry.size.width * 0.75
                                        )
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .padding(12)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .id(entry.id)
                            } else if entry.showMonsterSprite, let monster = entry.monsterForSprite {
                                VStack(spacing: 12) {
                                    MonsterSprite.spriteView(
                                        monsterName: monster.baseName,
                                        size: geometry.size.width * 0.75
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
                            } else {
                                // Check if this is a location entry (starts with "• ")
                                let isLocationEntry = entry.content.hasPrefix("• ")
                                let isTappable = isLocationEntry && engine.awaitingLocationSelection

                                if isTappable {
                                    // Extract location name from "• Name (Type): Description"
                                    let locationName = extractLocationName(from: entry.content)

                                    Button {
                                        if let name = locationName {
                                            Task {
                                                await engine.submitPlayer(input: name)
                                            }
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
                                } else {
                                    Text(entry.content)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(entry.isFromModel ? Color.secondary.opacity(0.1) : Color.accentColor.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .id(entry.id)
                                }
                            }
                        }

                        if engine.awaitingWorldContinue, engine.character != nil {
                            VStack(spacing: 16) {
                                Button {
                                    Task {
                                        let usedNames = getUsedCharacterNames()
                                        await engine.continueNewGame(usedNames: usedNames)
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
                        } else if engine.characterDied {
                            VStack(spacing: 16) {
                                Text("💀 Your Character Has Fallen")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.red)

                                if let report = engine.deathReport {
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
                        } else if engine.showingAdventureSummary {
                            VStack(spacing: 16) {
                                Text("🎉 Quest Complete!")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)

                                Button {
                                    showAdventureSummarySheet = true
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
                        } else if !engine.suggestedActions.isEmpty {
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
        .fullScreenCover(item: Binding(
            get: { engine.inCombat && engine.currentMonster != nil && engine.character != nil ? engine.currentMonster : nil },
            set: { _ in }
        )) { monster in
            if let character = engine.character {
                NavigationStack {
                    CombatView(
                        monster: monster,
                        currentMonsterHP: engine.currentMonsterHP,
                        character: character,
                        detailedInventory: engine.detailedInventory,
                        onAction: { action in
                            Task {
                                await handleCombatAction(action)
                            }
                        },
                        onFlee: {
                            let _ = engine.fleeCombat()
                        }
                    )
                    .background(Color(UIColor.systemBackground))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                engine.combatManager.inCombat = false
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showDeathReport) {
            deathReportView
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
                .presentationDetents([.medium, .large])
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
        .sheet(isPresented: $showAdventureSummarySheet) {
            if let summary = engine.adventureSummary {
                adventureSummarySheet(summary: summary)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
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

    private var actionsSheet: some View {
        VStack(spacing: 12) {
            Text("Choose Your Action")
                .font(.headline)
                .padding(.top, 8)

            ScrollViewReader { proxy in
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
                            .id(index == 0 ? "topAction" : nil)
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
                .onAppear {
                    proxy.scrollTo("topAction", anchor: .top)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func questSheet(progress: AdventureProgress) -> some View {
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
                        showQuestSheet = false
                    }
                }
            }
        }
    }

    private func adventureSummarySheet(summary: AdventureSummary) -> some View {
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
                            ForEach(summary.notableItems, id: \.self) { item in
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
                        showAdventureSummarySheet = false
                        engine.showingAdventureSummary = false
                        Task {
                            await engine.promptForNextLocation()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var deathReportView: some View {
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
                    },
                    engine: engine
                )
                .background(Color(UIColor.systemBackground))
            }
        }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if engine.character != nil, engine.adventureProgress != nil, !engine.awaitingWorldContinue {
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

    // MARK: - State Sharing
    @ViewBuilder
    private var stateToolbar: some View {
        HStack {
            Button {
                #if DEBUG
                dumpAdventureState()
                #else
                showMailComposer = true
                #endif
            } label: {
                HStack {
                    #if DEBUG
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Dump State")
                    #else
                    Image(systemName: "envelope")
                    Text("Email State")
                    #endif
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .sheet(isPresented: $showMailComposer) {
                MailComposeView(
                    subject: "DunGen Adventure State",
                    messageBody: buildAdventureStateText(),
                    isPresented: $showMailComposer
                )
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
    }

    private func buildAdventureStateText() -> String {
        var text = "========== ADVENTURE STATE DUMP ==========\n\n"

        if let char = engine.character {
            let level = levelingService.level(forXP: char.xp)
            text += "📜 CHARACTER:\n"
            text += "Name: \(char.name)\n"
            text += "Race: \(char.race) | Class: \(char.className)\n"
            text += "Level: \(level) | XP: \(char.xp)\n"
            text += "HP: \(char.hp)/\(char.maxHP)\n"
            text += "Gold: \(char.gold)\n"
        }

        if let progress = engine.adventureProgress {
            text += "\n🎯 ADVENTURE PROGRESS:\n"
            text += "Location: \(progress.locationName)\n"
            text += "Quest: \(progress.questGoal)\n"
            text += "Story: \(progress.adventureStory)\n"
            text += "Progress: \(progress.currentEncounter)/\(progress.totalEncounters)\n"
            text += "Completed: \(progress.completed)\n"

            text += "\n📖 ENCOUNTER SUMMARIES:\n"
            for (index, summary) in progress.encounterSummaries.enumerated() {
                text += "\(index + 1). \(summary)\n"
            }
        }

        text += "\n📝 NARRATIVE LOG (last 10 entries):\n"
        for entry in engine.log.suffix(10) {
            let prefix = entry.isFromModel ? "[MODEL]" : "[PLAYER]"
            text += "\(prefix) \(entry.content)\n"
        }

        if let monster = engine.currentMonster {
            text += "\n⚔️ CURRENT MONSTER:\n"
            text += "Name: \(monster.fullName)\n"
            text += "HP: \(engine.currentMonsterHP)/\(monster.hp)\n"
            text += "In Combat: \(engine.inCombat)\n"
        }

        if let transaction = engine.pendingTransaction {
            text += "\n💰 PENDING TRANSACTION:\n"
            text += "Items: \(transaction.items.joined(separator: ", "))\n"
            text += "Cost: \(transaction.cost) gold\n"
        }

        text += "\n========== END DUMP ==========\n"
        return text
    }

    private func dumpAdventureState() {
        print("\n" + buildAdventureStateText())
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

        if case .available = engine.availability {
            if engine.character == nil || engine.characterDied {
                let usedNames = getUsedCharacterNames()
                await engine.startNewGame(preferredType: engine.currentLocation, usedNames: usedNames)
            } else if engine.character != nil && engine.suggestedActions.isEmpty && !engine.inCombat && !engine.awaitingWorldContinue {
                await engine.submitPlayer(input: "continue")
            }
        }
    }

    private func getUsedCharacterNames() -> [String] {
        let descriptor = FetchDescriptor<DeceasedCharacter>()
        let deceasedCharacters = (try? modelContext.fetch(descriptor)) ?? []
        return deceasedCharacters.map { $0.name }
    }

    private func extractLocationName(from text: String) -> String? {
        // Extract location name from "• Name (Type): Description"
        guard text.hasPrefix("• ") else { return nil }
        let withoutBullet = text.dropFirst(2)
        if let parenIndex = withoutBullet.firstIndex(of: "(") {
            return String(withoutBullet[..<parenIndex]).trimmingCharacters(in: .whitespaces)
        }
        return nil
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
        case .useItem(let itemName):
            let success = engine.useItem(itemName: itemName)
            if success {
                await engine.performCombatAction("used item")
            }
        case .flee:
            let _ = engine.fleeCombat()
        case .surrender:
            engine.surrenderCombat()
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
