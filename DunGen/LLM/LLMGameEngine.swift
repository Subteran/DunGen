import Foundation
import SwiftUI
import FoundationModels
import OSLog

@MainActor
@Observable
final class LLMGameEngine: GameEngine {
    typealias LogEntry = GameLogEntry

    weak var delegate: GameEngineDelegate?
    private let gameplayLogger = GameplayLogger()

    // MARK: - Public State
    enum AvailabilityState: Equatable {
        case available
        case unavailable(String)
    }

    // MARK: - Core State (not delegated to managers)
    var log: [GameLogEntry] = []
    var lastPrompt: String = ""
    var worldState: WorldState?
    var character: CharacterProfile?
    var partialCharacter: CharacterProfile?

    var gameStartTime: Date?
    var adventuresCompleted: Int = 0
    var totalMonstersDefeated: Int = 0
    var totalXPEarned: Int = 0
    var totalGoldEarned: Int = 0

    var characterDied: Bool = false
    var deathReport: CharacterDeathReport?

    var pendingTransaction: PendingTransaction?

    var activeNPC: NPCDefinition?
    var activeNPCTurns: Int = 0

    private var knownItemAffixes: Set<String> = []
    private var knownMonsterAffixes: Set<String> = []

    var availability: AvailabilityState = .unavailable("Checking model…")

    // MARK: - Private

    internal let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "LLMGameEngine")
    nonisolated(unsafe) private let levelingService: LevelingServiceProtocol
    internal let disablePersistence: Bool

    // MARK: - Managers
    private let sessionManager = SpecialistSessionManager()
    let combatManager = CombatManager()
    let affixRegistry = AffixRegistry()
    let npcRegistry = NPCRegistry()
    private let narrativeProcessor = NarrativeProcessor()
    private let adventureState = AdventureStateManager()
    private let uiState = UIStateManager()
    private let encounterState = EncounterStateManager()
    private let inventoryState = InventoryStateManager()
    private let questValidator = QuestValidator()
    private var lootGenerator: LootGenerator?
    private var monsterGenerator: MonsterGenerator?
    private var npcGenerator: NPCGenerator?
    private let levelRewardGenerator = LevelRewardGenerator()
    private let inputHandler = PlayerInputHandler()
    private let turnProcessor = TurnProcessor()
    private let encounterOrchestrator = EncounterOrchestrator()
    private let questProgressManager = QuestProgressManager()

    var inCombat: Bool { combatManager.inCombat }
    var currentMonster: MonsterDefinition? { combatManager.currentMonster }
    var currentMonsterHP: Int { combatManager.currentMonsterHP }

    // MARK: - State Manager Proxies
    var adventureProgress: AdventureProgress? {
        get { adventureState.adventureProgress }
        set { adventureState.adventureProgress = newValue }
    }
    var currentAdventureXP: Int {
        get { adventureState.currentAdventureXP }
        set { adventureState.currentAdventureXP = newValue }
    }
    var currentAdventureGold: Int {
        get { adventureState.currentAdventureGold }
        set { adventureState.currentAdventureGold = newValue }
    }
    var currentAdventureMonsters: Int {
        get { adventureState.currentAdventureMonsters }
        set { adventureState.currentAdventureMonsters = newValue }
    }
    var adventureSummary: AdventureSummary? {
        get { adventureState.adventureSummary }
        set { adventureState.adventureSummary = newValue }
    }
    var showingAdventureSummary: Bool {
        get { adventureState.showingAdventureSummary }
        set { adventureState.showingAdventureSummary = newValue }
    }
    var currentLocation: AdventureType {
        get { adventureState.currentLocation }
        set { adventureState.currentLocation = newValue }
    }
    var currentEnvironment: String {
        get { adventureState.currentEnvironment }
        set { adventureState.currentEnvironment = newValue }
    }

    var isGenerating: Bool {
        get { uiState.isGenerating }
        set { uiState.isGenerating = newValue }
    }
    var suggestedActions: [String] {
        get { uiState.suggestedActions }
        set { uiState.suggestedActions = newValue }
    }
    var awaitingLocationSelection: Bool {
        get { uiState.awaitingLocationSelection }
        set { uiState.awaitingLocationSelection = newValue }
    }
    var awaitingCustomCharacterName: Bool {
        get { uiState.awaitingCustomCharacterName }
        set { uiState.awaitingCustomCharacterName = newValue }
    }
    var awaitingWorldContinue: Bool {
        get { uiState.awaitingWorldContinue }
        set { uiState.awaitingWorldContinue = newValue }
    }
    var needsInventoryManagement: Bool {
        get { uiState.needsInventoryManagement }
        set { uiState.needsInventoryManagement = newValue }
    }

    var detailedInventory: [ItemDefinition] {
        get { inventoryState.detailedInventory }
        set { inventoryState.detailedInventory = newValue }
    }
    var pendingLoot: [ItemDefinition] {
        get { inventoryState.pendingLoot }
        set { inventoryState.pendingLoot = newValue }
    }
    var itemsCollected: Int {
        get { inventoryState.itemsCollected }
        set { inventoryState.itemsCollected = newValue }
    }

    var pendingTrap: EncounterStateManager.PendingTrap? {
        get { encounterState.pendingTrap }
        set { encounterState.pendingTrap = newValue }
    }

    // MARK: - Internal Accessors for Persistence
    internal var encounterCounts: [String: Int] {
        get { encounterState.encounterCounts }
        set { encounterState.encounterCounts = newValue }
    }
    internal var lastEncounter: String? {
        get { encounterState.lastEncounter }
        set { encounterState.lastEncounter = newValue }
    }
    internal var encountersSinceLastTrap: Int {
        get { encounterState.encountersSinceLastTrap }
        set { encounterState.encountersSinceLastTrap = newValue }
    }

    // MARK: - Setup
    nonisolated init(levelingService: LevelingServiceProtocol, disablePersistence: Bool = false) {
        self.levelingService = levelingService
        self.disablePersistence = disablePersistence
    }

    nonisolated convenience init(disablePersistence: Bool = false) {
        self.init(levelingService: DefaultLevelingService(), disablePersistence: disablePersistence)
    }

    func setupManagers() {
        combatManager.setGameEngine(self)
        lootGenerator = LootGenerator(affixRegistry: affixRegistry)
        monsterGenerator = MonsterGenerator(affixRegistry: affixRegistry)
        npcGenerator = NPCGenerator(npcRegistry: npcRegistry)
        inputHandler.gameEngine = self
        turnProcessor.gameEngine = self
        encounterOrchestrator.gameEngine = self
    }

    func checkAvailabilityAndConfigure() {
        setupManagers()
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            self.availability = .available
            sessionManager.configureSessions()
        case .unavailable(let reason):
            self.availability = .unavailable("Model unavailable: \(reason)")
        }
    }

    func getCharacterLevel() -> Int {
        guard let char = character else { return 1 }
        return levelingService.level(forXP: char.xp)
    }

    private func getSession(for specialist: LLMSpecialist) -> LanguageModelSession? {
        return sessionManager.getSession(for: specialist)
    }

    private func setGenerating(_ generating: Bool) {
        uiState.setGenerating(generating)
        if generating {
            delegate?.engineDidStartGenerating()
        } else {
            delegate?.engineDidFinishGenerating()
        }
    }

    internal func updateSuggestedActions(_ actions: [String]) {
        uiState.updateSuggestedActions(actions)
        delegate?.engineDidUpdateSuggestedActions(actions)
    }

    private func updateLog() {
        delegate?.engineDidUpdateLog(log)
    }

    // MARK: - Game Flow
    func startNewGame(preferredType: AdventureType? = nil, usedNames: [String] = []) async {
        guard case .available = availability else { return }
        logger.info("=== STARTING NEW GAME - CLEARING ALL STATE ===")

        setGenerating(true)
        deleteState()

        log.removeAll()
        character = nil
        worldState = nil
        knownItemAffixes.removeAll()
        knownMonsterAffixes.removeAll()
        activeNPC = nil
        activeNPCTurns = 0
        combatManager.reset()
        affixRegistry.reset()
        npcRegistry.reset()
        sessionManager.resetAll()
        characterDied = false
        deathReport = nil
        gameStartTime = Date()
        adventuresCompleted = 0

        // Reset all state managers
        adventureState.reset()
        uiState.reset()
        encounterState.reset()
        inventoryState.reset()

        if let preferred = preferredType { currentLocation = preferred }

        do {
            guard let _ = getSession(for: .world),
                  let characterSession = getSession(for: .character) else { return }

            let races = ["Human", "Elf", "Dwarf", "Halfling", "Half-Elf", "Half-Orc", "Gnome", "Ursa"]
            let classes = ["Rogue", "Warrior", "Mage", "Healer", "Paladin", "Ranger", "Monk", "Bard", "Druid", "Necromancer", "Barbarian", "Warlock", "Sorcerer", "Cleric", "Assassin", "Berserker"]

            let randomRace = races.randomElement() ?? "Human"
            let randomClass = classes.randomElement() ?? "Warrior"

            let characterPrompt = "Create a new \(randomRace) \(randomClass) character for a fantasy text adventure. Generate name, personality, backstory, stats, equipment, abilities, and spells appropriate for a \(randomRace) \(randomClass)."
            logger.debug("[Character LLM] Prompt: \(randomRace) \(randomClass), length: \(characterPrompt.count) chars")

            var attempts = 0
            let maxAttempts = 5
            var generatedCharacter: CharacterProfile?
            var lastCandidate: CharacterProfile?

            while attempts < maxAttempts {
                let characterResponse = try await characterSession.respond(to: characterPrompt, generating: CharacterProfile.self)
                let candidate = characterResponse.content
                lastCandidate = candidate

                if !usedNames.contains(candidate.name) {
                    generatedCharacter = candidate
                    logger.debug("[Character LLM] Generated unique character: \(candidate.name) the \(candidate.className)")
                    break
                } else {
                    logger.debug("[Character LLM] Name '\(candidate.name)' already used, regenerating... (attempt \(attempts + 1))")
                    attempts += 1
                }
            }

            if let generatedCharacter {
                var char = generatedCharacter

                // Apply racial stat modifiers
                let modifiers = RaceModifiers.modifiers(for: char.race)
                char.attributes = modifiers.apply(to: char.attributes)

                char.hp = char.maxHP

                // Add starting items to detailed inventory with quantities
                var healingPotion = ItemDefinition(
                    baseName: "Healing Potion",
                    prefix: nil,
                    suffix: nil,
                    itemType: "consumable",
                    description: "A small vial of red liquid that restores health when consumed.",
                    rarity: "common",
                    consumableEffect: "hp",
                    consumableMinValue: 2,
                    consumableMaxValue: 5
                )
                healingPotion.quantity = 3
                detailedInventory.append(healingPotion)
                char.inventory.append(healingPotion.fullName)

                var bandage = ItemDefinition(
                    baseName: "Bandage",
                    prefix: nil,
                    suffix: nil,
                    itemType: "consumable",
                    description: "A clean cloth bandage that restores a small amount of health.",
                    rarity: "common",
                    consumableEffect: "hp",
                    consumableMinValue: 1,
                    consumableMaxValue: 3
                )
                bandage.quantity = 3
                detailedInventory.append(bandage)
                char.inventory.append(bandage.fullName)

                character = char
            } else {
                // Failed to generate unique name after max attempts
                logger.warning("[Character LLM] Failed to generate unique name after \(maxAttempts) attempts")
                partialCharacter = lastCandidate
                awaitingCustomCharacterName = true
                appendModel("\n⚠️ Unable to generate a unique character name automatically.")
                appendModel("Please enter a unique name for your character:")
                if let partial = partialCharacter {
                    delegate?.engineNeedsCustomCharacterName(partialCharacter: partial)
                }
                saveState()
                setGenerating(false)
                return
            }

            appendModel(L10n.gameWelcome)
            appendCharacterSprite()
            appendModel(String(format: L10n.gameIntroFormat, character!.name, character!.race, character!.className, character!.backstory))
            appendModel(String(format: L10n.startingAttributesFormat,
                               character!.attributes.strength,
                               character!.attributes.dexterity,
                               character!.attributes.constitution,
                               character!.attributes.intelligence,
                               character!.attributes.wisdom,
                               character!.attributes.charisma))

            awaitingWorldContinue = true
            delegate?.engineNeedsWorldContinue()
            saveState()
            setGenerating(false)
            return
        } catch {
            logger.error("\(error.localizedDescription, privacy: .public)")
            appendModel(String(format: L10n.errorStartGameFormat, error.localizedDescription))
        }
        setGenerating(false)
    }

    func continueNewGame(usedNames: [String] = []) async {
        guard case .available = availability else { return }

        setGenerating(true)

        do {
            if awaitingWorldContinue {
                awaitingWorldContinue = false

                guard let worldSession = getSession(for: .world) else {
                    setGenerating(false)
                    return
                }

                let worldPrompt = "Create a fantasy world with an engaging story and diverse starting locations."
                logger.debug("[World LLM - Initial] Prompt length: \(worldPrompt.count) chars")
                let worldResponse = try await worldSession.respond(to: worldPrompt, generating: WorldState.self)
                logger.debug("[World LLM - Initial] Generated \(worldResponse.content.locations.count) locations")

                var world = worldResponse.content
                world.locations = world.locations.map { location in
                    var loc = location
                    loc.visited = false
                    loc.completed = false
                    return loc
                }
                worldState = world

                if let world = worldState {
                    appendModel("\u{1F30D} \(world.worldStory)")
                    appendModel("\nDiscovered locations:")
                    for location in world.locations {
                        appendModel("• \(location.name) (\(location.locationType.rawValue)): \(location.description)")
                    }
                    appendModel("\nWhere would you like to begin your adventure?")
                    updateSuggestedActions(world.locations.map { $0.name })
                    awaitingLocationSelection = true
                }

                saveState()
            }
        } catch {
            logger.error("\(error.localizedDescription, privacy: .public)")
            appendModel(String(format: L10n.errorStartGameFormat, error.localizedDescription))
        }

        setGenerating(false)
    }

    func submitPlayer(input: String) async {
        guard case .available = availability else { return }
        guard !characterDied else { return }
        guard let adventureSession = getSession(for: .adventure), !adventureSession.isResponding else { return }

        // Recovery: If quest is completed but summary was dismissed without selecting location
        if let progress = adventureProgress, progress.completed, !showingAdventureSummary, !awaitingLocationSelection {
            await promptForNextLocation()
            return
        }

        let truncatedInput = input.count > 500 ? String(input.prefix(500)) : input

        setGenerating(true)
        updateSuggestedActions([])
        appendPlayer(truncatedInput)

        if awaitingCustomCharacterName {
            if await inputHandler.handleCharacterNameInput(truncatedInput, partialCharacter: partialCharacter) {
                setGenerating(false)
                return
            }
            setGenerating(false)
            return
        }

        guard character != nil else { return }

        if let pendingMonster = combatManager.pendingMonster {
            if let result = await inputHandler.handleFleeFromPendingMonster(truncatedInput, pendingMonster: pendingMonster) {
                if case .continueToAdvanceScene(let action) = result {
                    do {
                        try await advanceScene(kind: currentLocation, playerAction: action)
                        saveState()
                    } catch {
                        logger.error("\(error.localizedDescription, privacy: .public)")
                        appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
                    }
                }
                saveState()
                setGenerating(false)
                return
            }
        }

        if let transaction = pendingTransaction {
            if let result = await inputHandler.handlePendingTransaction(truncatedInput, transaction: transaction) {
                if case .continueToAdvanceScene(let action) = result {
                    do {
                        try await advanceScene(kind: currentLocation, playerAction: action)
                        saveState()
                    } catch {
                        logger.error("\(error.localizedDescription, privacy: .public)")
                        appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
                    }
                }
                saveState()
                setGenerating(false)
                return
            }
        }

        if let pendingMonster = combatManager.pendingMonster {
            if let result = await inputHandler.handlePendingMonsterCombat(truncatedInput, pendingMonster: pendingMonster) {
                if case .continueToAdvanceScene = result {
                } else {
                    saveState()
                    setGenerating(false)
                    return
                }
            }
        }

        if let trap = pendingTrap {
            if let result = await inputHandler.handlePendingTrap(truncatedInput, trap: trap) {
                if case .continueToAdvanceScene(let action) = result {
                    do {
                        try await advanceScene(kind: currentLocation, playerAction: action)
                        saveState()
                    } catch {
                        logger.error("\(error.localizedDescription, privacy: .public)")
                        appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
                    }
                }
                saveState()
                setGenerating(false)
                return
            }
        }

        if let result = await inputHandler.handleActiveCombat(truncatedInput) {
            if case .continueToAdvanceScene(let action) = result {
                do {
                    try await advanceScene(kind: currentLocation, playerAction: action)
                    saveState()
                } catch {
                    logger.error("\(error.localizedDescription, privacy: .public)")
                    appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
                }
            }
            saveState()
            setGenerating(false)
            return
        }

        if let result = await inputHandler.handleLocationSelection(truncatedInput) {
            if case .continueToAdvanceScene(let action) = result {
                do {
                    try await advanceScene(kind: currentLocation, playerAction: action)
                    saveState()
                } catch {
                    logger.error("\(error.localizedDescription, privacy: .public)")
                    appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
                }
            }
            saveState()
            setGenerating(false)
            return
        }

        do {
            try await advanceScene(kind: currentLocation, playerAction: truncatedInput)
            saveState()
        } catch {
            logger.error("\(error.localizedDescription, privacy: .public)")
            appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
        }
        setGenerating(false)
    }

    func apply(turn: AdventureTurn, encounter: EncounterDetails?, rewards: ProgressionRewards?, loot: [ItemDefinition], monster: MonsterDefinition?, npc: NPCDefinition?, playerAction: String? = nil) async {
        if let encounterType = encounter?.encounterType {
            trackEncounter(encounterType)
        }

        storeEncounterKeywords(turn: turn, encounter: encounter, monster: monster, npc: npc)

        turnProcessor.processAdventureProgress(turn: turn)

        await turnProcessor.handleQuestCompletion(playerAction: playerAction, turn: turn, questValidator: questValidator)

        if var currentProgress = adventureProgress {
            currentProgress.currentEncounter += 1
            adventureProgress = currentProgress
        }

        if adventureProgress != nil {
            let summary = generateEncounterSummary(
                narrative: turn.narration,
                encounterType: encounter?.encounterType ?? "unknown",
                monster: monster,
                npc: npc
            )
            adventureProgress?.encounterSummaries.append(summary)
        }

        await turnProcessor.handleFinalEncounterCompletion(encounterSummaryGenerator: generateEncounterSummary)

        if let monster = monster {
            turnProcessor.setupMonsterEncounter(monster: monster, turn: turn)
        } else {
            updateSuggestedActions(turn.suggestedActions)
        }

        if let npc = npc {
            appendModel("\n💬 NPC: \(npc.name) the \(npc.occupation)")
            if npc.interactionCount > 0 {
                appendModel("(You've met \(npc.interactionCount) time\(npc.interactionCount == 1 ? "" : "s") before)")
            }
        }

        let encounterType = encounter?.encounterType.lowercased() ?? ""
        let isTrapEncounter = encounterType == "trap"
        let isSocialEncounter = encounterType == "social"
        let isCombatEncounter = encounterType == "combat"

        if isTrapEncounter, let rewards = rewards {
            turnProcessor.setupTrapEncounter(rewards: rewards, turn: turn)
        }

        let shouldApplyRewards = monster == nil && !isTrapEncounter && !isCombatEncounter

        var justLeveledUp = false
        if shouldApplyRewards, let rewards = rewards {
            justLeveledUp = await turnProcessor.applyXPRewards(rewards: rewards, isSocialEncounter: isSocialEncounter, levelingService: levelingService)
        }

        if shouldApplyRewards, let rewards = rewards {
            let characterDied = turnProcessor.applyHPRewards(rewards: rewards, isSocialEncounter: isSocialEncounter, justLeveledUp: justLeveledUp)
            if characterDied {
                return
            }
        }

        if shouldApplyRewards, let rewards = rewards {
            turnProcessor.applyGoldRewards(rewards: rewards, isSocialEncounter: isSocialEncounter)
        }

        // CRITICAL: Never process item purchases during combat encounters
        if !isCombatEncounter {
            await turnProcessor.handleItemAcquisition(turn: turn, npc: npc)
        }

        if shouldApplyRewards {
            turnProcessor.handleLootDistribution(loot: loot, maxInventorySlots: inventoryState.maxInventorySlots)
        }

        turnProcessor.updateEnvironment(from: turn, encounterType: encounter?.encounterType)

        let cleanedNarration = sanitizeNarration(turn.narration, for: encounter?.encounterType)
        appendModel(cleanedNarration)
        if let prompt = turn.playerPrompt, !prompt.isEmpty {
            appendModel(prompt)
        }
    }

    internal func checkQuestCompletion(itemsAcquired: [String]?) async {
        guard var progress = adventureProgress else { return }

        if let result = questValidator.validateQuestCompletion(progress: progress, itemsAcquired: itemsAcquired) {
            progress.completed = true
            adventureProgress = progress

            logger.info("[Quest] Retrieval quest auto-completed: acquired '\(result.completingItem)'")
            appendModel("\n✅ Quest Objective Achieved!")
            appendModel("The quest '\(result.questGoal)' is now complete.")

            adventuresCompleted += 1

            // Update lifetime stats
            totalXPEarned += currentAdventureXP
            totalGoldEarned += currentAdventureGold
            totalMonstersDefeated += currentAdventureMonsters

            if var world = worldState {
                world.locations.removeAll(where: { $0.name == result.locationName })
                worldState = world
            }

            combatManager.pendingMonster = nil
            activeNPC = nil
            activeNPCTurns = 0
            pendingTrap = nil

            await generateAdventureSummary(progress: progress)
        }
    }

    private func trackEncounter(_ type: String) {
        encounterState.trackEncounter(type)
    }

    internal func generateLevelReward(for className: String, level: Int) async {
        guard var character = self.character else { return }

        let specialist: LLMSpecialist
        switch className.lowercased() {
        case "mage", "necromancer":
            specialist = .spells
        case "healer", "paladin":
            specialist = .prayers
        case "druid":
            specialist = .spells
        default:
            specialist = .abilities
        }

        guard let session = getSession(for: specialist) else { return }

        do {
            if let result = try await levelRewardGenerator.generateLevelReward(
                session: session,
                character: character,
                className: className,
                level: level
            ) {
                switch result.rewardType {
                case .spell:
                    character.spells.append(result.rewardName)
                    appendModel("📜 New Spell Learned: \(result.rewardName)")
                case .prayer:
                    character.spells.append(result.rewardName)
                    appendModel("✨ New Prayer Granted: \(result.rewardName)")
                case .ability:
                    character.abilities.append(result.rewardName)
                    appendModel("⚡️ New Ability Gained: \(result.rewardName)")
                }

                self.character = character
                saveState()
            }
        } catch {
            logger.error("Failed to generate level reward: \(error.localizedDescription, privacy: .public)")
        }
    }


    private func generateMonster(for encounter: EncounterDetails, characterLevel: Int, location: String) async throws -> MonsterDefinition? {
        guard let monsterSession = getSession(for: .monsters) else { return nil }
        guard let generator = monsterGenerator else { return nil }

        return try await generator.generateMonster(
            session: monsterSession,
            encounter: encounter,
            characterLevel: characterLevel,
            location: location
        )
    }

    private func generateOrRetrieveNPC(for location: String, encounter: EncounterDetails) async throws -> NPCDefinition? {
        guard let npcSession = getSession(for: .npc) else { return nil }
        guard let generator = npcGenerator else { return nil }

        return try await generator.generateOrRetrieveNPC(
            session: npcSession,
            location: location,
            encounter: encounter
        )
    }

    private func generateLoot(count: Int, difficulty: String, characterLevel: Int, characterClass: String) async throws -> [ItemDefinition] {
        guard let equipmentSession = getSession(for: .equipment),
              let generator = lootGenerator else { return [] }

        let items = try await generator.generateLoot(
            count: count,
            difficulty: difficulty,
            characterLevel: characterLevel,
            characterClass: characterClass,
            existingInventory: detailedInventory,
            equipmentSession: equipmentSession
        )

        // Update knownItemAffixes for backward compatibility
        for item in items {
            if let prefix = item.prefix {
                knownItemAffixes.insert(prefix.name)
            }
            if let suffix = item.suffix {
                knownItemAffixes.insert(suffix.name)
            }
        }

        return items
    }

    private func buildEncounterContext(monster: MonsterDefinition?, npc: NPCDefinition?) -> String {
        var context = ""

        if let monster = monster {
            context += "\nMonster: \(monster.fullName) (HP: \(monster.hp), Damage: \(monster.damage), Defense: \(monster.defense))"
            if !monster.abilities.isEmpty {
                context += "\nAbilities: \(monster.abilities.joined(separator: ", "))"
            }
        }

        if let npc = npc {
            context += "\nNPC: \(npc.name) (\(npc.occupation))"
            context += "\nAppearance: \(npc.appearance)"
            context += "\nPersonality: \(npc.personality)"
            context += "\nRelationship: \(npc.relationshipStatus)"
            if npc.interactionCount > 0 {
                context += "\nPrevious interactions: \(npc.interactionCount)"
            }
        }

        return context
    }

    func performCombatAction(_ action: String) async {
        let wasInCombat = combatManager.inCombat
        combatManager.performCombatAction(action)

        // Check if character died during combat
        if characterDied {
            saveState()
            return
        }

        if wasInCombat && !combatManager.inCombat {
            saveState()
            if let char = character, char.hp > 0, !characterDied {
                appendModel("\n🎯 Continuing your adventure...")
                try? await Task.sleep(nanoseconds: 500_000_000)
                await submitPlayer(input: "continue")
            }
        }
    }

    func applyMonsterDefeatRewards(monster: MonsterDefinition) {
        guard var char = character else { return }
        guard !characterDied else { return }

        currentAdventureMonsters += 1

        if let progress = adventureProgress, progress.isFinalEncounter {
            let questLower = progress.questGoal.lowercased()
            if questLower.contains("defeat") || questLower.contains("kill") || questLower.contains("destroy") || questLower.contains("stop") || questLower.contains("eliminate") {
                var updatedProgress = progress
                updatedProgress.completed = true
                adventureProgress = updatedProgress
                appendModel("\n🎉 Quest Complete: \(progress.questGoal)")
                logger.info("[Quest] Combat quest completed via boss defeat")
            }
        }

        let charLevel = levelingService.level(forXP: char.xp)
        let baseXP = 10 + (charLevel * 5)
        let xpVariance = Int.random(in: -3...10)
        let xpGain = max(5, baseXP + xpVariance)

        currentAdventureXP += xpGain
        let outcome = levelingService.applyXPGain(xpGain, to: &char)
        character = char
        if outcome.didLevelUp {
            appendModel(outcome.logLine)
            if outcome.needsNewAbility {
                let className = char.className
                let newLevel = outcome.newLevel ?? 1
                Task {
                    await generateLevelReward(for: className, level: newLevel)
                }
            }
        } else {
            appendModel("✨ Gained \(xpGain) XP!")
        }

        let goldGain = Int.random(in: 5...25)
        currentAdventureGold += goldGain
        char.gold += goldGain
        character = char
        appendModel("💰 Found \(goldGain) gold!")

        let shouldDropLoot = Int.random(in: 1...100) <= 30
        if shouldDropLoot {
            let classNameForLoot = char.className
            Task {
                do {
                    let loot = try await generateLoot(count: 1, difficulty: "medium", characterLevel: charLevel, characterClass: classNameForLoot)
                    if !loot.isEmpty {
                        let currentInventoryCount = detailedInventory.count
                        if currentInventoryCount + loot.count > inventoryState.maxInventorySlots {
                            pendingLoot = loot
                            needsInventoryManagement = true
                            delegate?.engineNeedsInventoryManagement(pendingLoot: loot, currentInventory: detailedInventory)
                            appendModel("⚠️ Inventory full! You need to make room for new items.")
                        } else {
                            for item in loot {
                                detailedInventory.append(item)
                                character?.inventory.append(item.fullName)
                                appendModel("✨ Obtained: \(item.fullName) (\(item.rarity))")
                                itemsCollected += 1
                            }
                        }
                        saveState()
                    }
                } catch {
                    logger.error("Failed to generate combat loot: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        saveState()
    }

    func fleeCombat() -> Bool {
        return combatManager.fleeCombat()
    }

    func surrenderCombat() {
        combatManager.surrenderCombat()
    }

    func useItem(itemName: String) -> Bool {
        guard var char = character else { return false }

        // Check if item exists in inventory
        guard char.inventory.contains(itemName) else { return false }

        // Find the item in detailed inventory
        guard let item = detailedInventory.first(where: { $0.fullName == itemName || $0.baseName == itemName }) else {
            return false
        }

        // Check if item is consumable
        guard item.itemType.lowercased() == "consumable",
              let effect = item.consumableEffect,
              let minValue = item.consumableMinValue,
              let maxValue = item.consumableMaxValue else {
            return false
        }

        // Calculate effect value
        let effectValue = Int.random(in: minValue...maxValue)

        // Apply effect based on type
        switch effect.lowercased() {
        case "hp":
            char.hp += effectValue
            char.hp = min(char.hp, char.maxHP)
            appendModel("💚 Used \(itemName) and healed \(effectValue) HP!")
        case "gold":
            char.gold += effectValue
            appendModel("💰 Used \(itemName) and gained \(effectValue) gold!")
        case "xp":
            let outcome = levelingService.applyXPGain(effectValue, to: &char)
            character = char
            if outcome.didLevelUp {
                appendModel("✨ Used \(itemName) and gained \(effectValue) XP!")
                appendModel(outcome.logLine)
                if outcome.needsNewAbility {
                    let className = char.className
                    let newLevel = outcome.newLevel ?? 1
                    Task {
                        await generateLevelReward(for: className, level: newLevel)
                    }
                }
            } else {
                appendModel("✨ Used \(itemName) and gained \(effectValue) XP!")
            }
        default:
            return false
        }

        // Decrement quantity or remove if last one
        if let index = detailedInventory.firstIndex(where: { $0.fullName == itemName || $0.baseName == itemName }) {
            detailedInventory[index].quantity -= 1

            if detailedInventory[index].quantity <= 0 {
                // Remove from both inventories when quantity reaches 0
                detailedInventory.remove(at: index)
                if let charIndex = char.inventory.firstIndex(of: itemName) {
                    char.inventory.remove(at: charIndex)
                }
            }
        }

        character = char
        saveState()
        return true
    }

    func finalizeInventorySelection(_ selectedItems: [ItemDefinition]) {
        detailedInventory = selectedItems
        character?.inventory = selectedItems.map { $0.fullName }

        let keptCount = selectedItems.count
        let discardedCount = (detailedInventory.count + pendingLoot.count) - keptCount
        itemsCollected += pendingLoot.count

        appendModel("✅ Kept \(keptCount) items, discarded \(discardedCount) items.")

        pendingLoot.removeAll()
        needsInventoryManagement = false
        saveState()
    }

    func checkDeath() {
        guard let char = character else { return }

        if char.hp <= 0 {
            characterDied = true
            let playTime = gameStartTime.map { Date().timeIntervalSince($0) } ?? 0

            deathReport = CharacterDeathReport(
                character: char,
                finalLevel: levelingService.level(forXP: char.xp),
                adventuresCompleted: adventuresCompleted,
                monstersDefeated: combatManager.monstersDefeated,
                itemsCollected: itemsCollected,
                causeOfDeath: combatManager.inCombat ? "Defeated by \(combatManager.currentMonster?.fullName ?? "unknown enemy")" : "Succumbed to injuries",
                playTime: playTime
            )

            if let report = deathReport {
                delegate?.engineDidDetectDeath(report: report)
            }

            combatManager.reset()
            appendModel("\n💀 You have fallen...")
        }
    }

    internal func handleCharacterDeath(monster: MonsterDefinition) {
        guard let char = character else { return }

        characterDied = true
        let playTime = gameStartTime.map { Date().timeIntervalSince($0) } ?? 0

        deathReport = CharacterDeathReport(
            character: char,
            finalLevel: levelingService.level(forXP: char.xp),
            adventuresCompleted: adventuresCompleted,
            monstersDefeated: combatManager.monstersDefeated,
            itemsCollected: itemsCollected,
            causeOfDeath: "Defeated by \(monster.fullName)",
            playTime: playTime
        )

        if let report = deathReport {
            delegate?.engineDidDetectDeath(report: report)
        }

        combatManager.reset()
        appendModel("\n💀 You have fallen...")
    }

    internal func shouldMonsterAttack(monster: MonsterDefinition, playerAction: String) async -> Bool {
        guard let encounterSession = getSession(for: .encounter) else { return true }

        let evaluationPrompt = """
        A \(monster.fullName) has encountered the player.
        Player's action: "\(playerAction)"

        Evaluate if this action would prevent or distract the monster from attacking.

        Actions that PREVENT attack (attacks = false):
        - Calming, pacifying, or befriending (talk peacefully, calm down, soothe)
        - Hiding or sneaking away (hide, sneak, stealth)
        - Creating barriers or obstacles (block, barricade, create wall)
        - Distracting with objects or magic (throw food, distract, create illusion)
        - Intimidating or scaring (intimidate, threaten, scare if believable)
        - Negotiating or reasoning (negotiate, reason, bargain)

        Actions that DO NOT prevent attack (attacks = true):
        - Searching or investigating (search, look around, examine)
        - Gathering items (pick up, collect, take)
        - Reading or studying (read, study, analyze)
        - Moving without stealth (walk, run without hiding)
        - Any action that leaves player vulnerable

        Consider the monster's nature and intelligence when evaluating.
        Smarter monsters are harder to fool. Aggressive monsters are harder to calm.

        Determine if the monster attacks.
        """

        do {
            let decision = try await encounterSession.respond(to: evaluationPrompt, generating: MonsterAttackDecision.self)
            return decision.content.attacks
        } catch {
            logger.error("Failed to evaluate monster attack: \(error.localizedDescription, privacy: .public)")
            return true
        }
    }
    
    // MARK: - Encounter variety helpers
    
    private func lastEncounterType() -> String? {
        return lastEncounter
    }

    private func countSinceLastTrap() -> Int {
        return encountersSinceLastTrap
    }

    private func enforceEncounterVariety(on encounter: inout EncounterDetails) {
        // NEVER override final encounters - they are critical for quest completion
        if encounter.encounterType == "final" {
            return
        }

        // Check if this is the final encounter based on adventure progress
        if let adventure = adventureProgress, adventure.isFinalEncounter {
            // Don't enforce variety on final encounters - respect the quest type requirements
            return
        }

        // Prevent consecutive combat unless it's a final encounter
        if encounter.encounterType == "combat", encounterState.lastEncounterType() == "combat" {
            // Coerce to exploration to break up combat streaks
            encounter = EncounterDetails(encounterType: "exploration", difficulty: encounter.difficulty)
        }
        // Prevent consecutive social encounters (too many NPCs)
        if encounter.encounterType == "social", encounterState.lastEncounterType() == "social" {
            // Coerce to exploration to break up NPC streaks
            encounter = EncounterDetails(encounterType: "exploration", difficulty: encounter.difficulty)
        }
        // Enforce 3+ non-trap encounters between traps
        if encounter.encounterType == "trap" {
            if encounterState.countSinceLastTrap() < 3 {
                encounter = EncounterDetails(encounterType: "exploration", difficulty: encounter.difficulty)
            }
        }
    }

    private func sanitizeNarration(_ text: String, for encounterType: String?) -> String {
        return narrativeProcessor.sanitizeNarration(text, for: encounterType)
    }

    private func smartTruncatePrompt(_ prompt: String, maxLength: Int) -> String {
        return narrativeProcessor.smartTruncatePrompt(prompt, maxLength: maxLength)
    }

    private func advanceScene(kind: AdventureType, playerAction: String?) async throws {
        guard let adventureSession = getSession(for: .adventure),
              let encounterSession = getSession(for: .encounter) else { return }

        // Check if quest is already completed - if so, don't generate new encounters
        if let progress = adventureProgress, progress.completed {
            // If summary hasn't been generated yet, generate it first
            if adventureSummary == nil {
                await generateAdventureSummary(progress: progress)
            }
            // Only prompt for next location if summary has been dismissed
            if !showingAdventureSummary {
                await promptForNextLocation()
            }
            return
        }

        // Check if quest has already failed - if so, don't generate new encounters
        if let progress = adventureProgress, questProgressManager.checkQuestFailure(adventure: progress) {
            appendModel("\n❌ Quest Failed: You were unable to complete '\(progress.questGoal)' in time.")
            appendModel("The opportunity has passed...")

            if var world = worldState {
                if let index = world.locations.firstIndex(where: { $0.name == progress.locationName }) {
                    world.locations[index].visited = true
                }
                worldState = world
            }

            let failedSummary = questProgressManager.createFailedQuestSummary(
                adventure: progress,
                currentAdventureXP: currentAdventureXP,
                currentAdventureGold: currentAdventureGold,
                currentAdventureMonsters: currentAdventureMonsters,
                recentItems: Array(detailedInventory.suffix(5).map { $0.fullName })
            )
            adventureSummary = failedSummary
            showingAdventureSummary = true
            return
        }

        sessionManager.incrementTurnCount()
        sessionManager.resetIfNeeded()

        let actionLine = playerAction.map { "Player action: \($0)" } ?? "Begin scene"
        let location = kind.rawValue
        let charLevel = levelingService.level(forXP: character?.xp ?? 0)

        var encounter: EncounterDetails
        var monster: MonsterDefinition?
        var npc: NPCDefinition?

        // Check if continuing an active NPC conversation
        let isContinuingConversation = encounterOrchestrator.shouldContinueNPCConversation(
            activeNPC: activeNPC,
            activeNPCTurns: activeNPCTurns,
            playerAction: playerAction
        )

        if isContinuingConversation {
            // Continue existing social encounter with same NPC
            encounter = EncounterDetails(encounterType: "social", difficulty: "normal")
            npc = activeNPC
            activeNPCTurns += 1
            logger.debug("[Encounter] Continuing conversation with \(npc?.name ?? "NPC") (turn \(self.activeNPCTurns))")
        } else {
            // Clear active NPC if needed
            if activeNPC != nil && !isContinuingConversation {
                logger.debug("[Encounter] Ending conversation with \(self.activeNPC?.name ?? "NPC")")
                activeNPC = nil
                activeNPCTurns = 0
            }

            encounter = try await encounterOrchestrator.generateEncounter(
                session: encounterSession,
                adventure: adventureProgress,
                character: character,
                characterLevel: charLevel,
                location: location,
                encounterCounts: encounterCounts,
                enforceVariety: enforceEncounterVariety
            )

            if encounter.encounterType == "combat" {
                activeNPC = nil
                activeNPCTurns = 0
                monster = try await generateMonster(for: encounter, characterLevel: charLevel, location: location)
            } else if encounter.encounterType == "final" {
                // Final encounter for non-combat quest completion (finding artifact, solving mystery, etc.)
                // No monster generation - the Adventure LLM will present the quest objective
                activeNPC = nil
                activeNPCTurns = 0
                combatManager.pendingMonster = nil
            } else if encounter.encounterType == "social" {
                npc = try await generateOrRetrieveNPC(for: location, encounter: encounter)
                activeNPC = npc
                activeNPCTurns = 1
                combatManager.pendingMonster = nil
            } else {
                activeNPC = nil
                activeNPCTurns = 0
                combatManager.pendingMonster = nil
            }
        }

        let recentActions = extractRecentKeywords()
        let locationName = currentEnvironment.isEmpty ? location : currentEnvironment
        let adventureContext = ContextBuilder.buildContext(
            for: .adventure,
            character: character,
            characterLevel: charLevel,
            adventure: adventureProgress,
            location: locationName,
            encounterType: encounter.encounterType,
            difficulty: encounter.difficulty,
            recentActions: recentActions,
            encounterCounts: encounterCounts,
            questGoal: adventureProgress?.questGoal
        )

        var scenePrompt = "\(locationName) location. \(actionLine)\n\(adventureContext)" + buildEncounterContext(monster: monster, npc: npc)

        // Add quest progression guidance based on encounter number
        if let adventure = adventureProgress {
            scenePrompt += questProgressManager.buildQuestProgressionGuidance(for: adventure)
        }

        scenePrompt += "\nCRITICAL: ONLY describe monsters if 'Monster:' appears above. For exploration/social/puzzle encounters, NO monsters exist - focus on environment, clues, NPCs, or challenges. Combat/final encounters will have 'Monster:' explicitly listed. Keep narration to EXACTLY 2-4 sentences."

        // Smart truncation to preserve critical instructions
        let maxPromptLength = 600
        if scenePrompt.count > maxPromptLength {
            logger.warning("[Adventure LLM] Prompt too long (\(scenePrompt.count) chars), applying smart truncation to \(maxPromptLength)")
            logger.warning("[Adventure LLM] Original prompt before truncation:\n\(scenePrompt)")
            scenePrompt = smartTruncatePrompt(scenePrompt, maxLength: maxPromptLength)
            logger.warning("[Adventure LLM] Truncated prompt:\n\(scenePrompt)")
        }

        logger.debug("[Adventure LLM] Prompt length: \(scenePrompt.count) chars")
        lastPrompt = scenePrompt
        let adventureResponse = try await adventureSession.respond(to: scenePrompt, generating: AdventureTurn.self)
        let turn = adventureResponse.content
        logger.debug("[Adventure LLM] Success")
        
        var sanitizedTurn = turn
        sanitizedTurn.narration = sanitizeNarration(turn.narration, for: encounter.encounterType)

        let isFinal = adventureProgress?.isFinalEncounter ?? false
        let rewards = RewardCalculator.calculateRewards(
            encounterType: encounter.encounterType,
            difficulty: encounter.difficulty,
            characterLevel: charLevel,
            currentHP: character?.hp ?? 0,
            maxHP: character?.maxHP ?? 0,
            isFinalEncounter: isFinal
        )
        logger.debug("[Reward Calculator] \(encounter.encounterType) (\(encounter.difficulty)): XP=\(rewards.xpGain), HP=\(rewards.hpDelta), Gold=\(rewards.goldGain)")

        var items: [ItemDefinition] = []
        if rewards.shouldDropLoot && rewards.itemDropCount > 0 {
            items = try await generateLoot(count: rewards.itemDropCount, difficulty: encounter.difficulty, characterLevel: charLevel, characterClass: character?.className ?? "Warrior")
        }

        // If the adventure is marked as completed, clear the pending monster before applying
        var finalMonster = monster
        if let progress = turn.adventureProgress, progress.completed {
            finalMonster = nil
        }

        await self.apply(turn: sanitizedTurn, encounter: encounter, rewards: rewards, loot: items, monster: finalMonster, npc: npc, playerAction: playerAction)
    }

    private func generateEncounterSummary(narrative: String, encounterType: String, monster: MonsterDefinition?, npc: NPCDefinition?) -> String {
        // Create short summaries for specific encounter types
        if let monster = monster {
            return "Encountered \(monster.fullName)"
        } else if let npc = npc {
            return "Met \(npc.name) the \(npc.occupation)"
        } else if encounterType == "trap" {
            return "Triggered trap"
        } else if encounterType == "puzzle" {
            return "Solved puzzle"
        }

        let cleaned = narrative
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let sentences = cleaned.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let firstSentence = sentences.first, !firstSentence.isEmpty {
            let maxLength = 60
            if firstSentence.count <= maxLength {
                return firstSentence
            }
            var truncated = String(firstSentence.prefix(maxLength))
            if let lastSpace = truncated.lastIndex(of: " ") {
                truncated = String(truncated[..<lastSpace])
            }
            return truncated + "..."
        }

        return String(cleaned.prefix(60)) + "..."
    }

    private func buildAdventureHistory() -> String {
        guard let progress = adventureProgress, !progress.encounterSummaries.isEmpty else {
            return ""
        }

        return progress.encounterSummaries.suffix(2).joined(separator: " → ")
    }

    private func buildContextSummary() -> String {
        guard let character = character else { return "" }

        var lines: [String] = []

        lines.append("Character: \(character.name) Lvl\(levelingService.level(forXP: character.xp)) \(character.className) HP:\(character.hp) Gold:\(character.gold)")

        if !currentEnvironment.isEmpty {
            lines.append("Current Location: \(currentEnvironment)")
        }

        if let adventure = adventureProgress {
            lines.append("Quest: \(adventure.questGoal)")
            lines.append("Progress: \(adventure.currentEncounter)/\(adventure.totalEncounters)")
        }

        if !detailedInventory.isEmpty {
            let itemNames = detailedInventory.prefix(3).map { $0.displayName }.joined(separator: ", ")
            let truncated = itemNames.count > 100 ? String(itemNames.prefix(100)) + "..." : itemNames
            lines.append("Items: \(truncated)")
        }

        if !character.abilities.isEmpty {
            let abilities = character.abilities.prefix(2).joined(separator: ", ")
            lines.append("Abilities: \(abilities)")
        }

        if !character.spells.isEmpty {
            let spells = character.spells.prefix(2).joined(separator: ", ")
            lines.append("Spells: \(spells)")
        }

        let recentKeywords = extractRecentKeywords()
        if !recentKeywords.isEmpty {
            lines.append("Recent: \(recentKeywords)")
        }

        return lines.joined(separator: "\n")
    }

    private func extractRecentKeywords() -> String {
        let recentEntries = log.suffix(4)
        var keywords: [String] = []

        for entry in recentEntries {
            let content = entry.content
            let keywordList = extractKeywords(from: content, isPlayerAction: !entry.isFromModel)
            if !keywordList.isEmpty {
                keywords.append(keywordList)
            }
        }

        let combined = keywords.joined(separator: ", ")
        return combined.count > 100 ? String(combined.prefix(100)) + "..." : combined
    }

    private func extractKeywords(from text: String, isPlayerAction: Bool) -> String {
        let lowercased = text.lowercased()
        var keywords: [String] = []

        let actionVerbs = ["attack", "fight", "flee", "run", "talk", "speak", "search", "investigate",
                          "open", "take", "use", "cast", "drink", "eat", "hide", "sneak", "climb"]
        let entities = ["monster", "goblin", "rat", "skeleton", "zombie", "orc", "dragon",
                       "chest", "door", "trap", "room", "corridor", "stairs", "npc"]
        let outcomes = ["defeated", "killed", "found", "discovered", "took damage", "healed",
                       "gained", "lost", "escaped", "failed", "succeeded"]

        for verb in actionVerbs {
            if lowercased.contains(verb) {
                keywords.append(verb)
                break
            }
        }

        for entity in entities {
            if lowercased.contains(entity) {
                keywords.append(entity)
            }
        }

        if !isPlayerAction {
            for outcome in outcomes {
                if lowercased.contains(outcome) {
                    keywords.append(outcome)
                    break
                }
            }
        }

        return keywords.prefix(3).joined(separator: " ")
    }

    private func storeEncounterKeywords(turn: AdventureTurn, encounter: EncounterDetails?, monster: MonsterDefinition?, npc: NPCDefinition?) {
        var keywords: [String] = []

        if let encounterType = encounter?.encounterType {
            keywords.append(encounterType)
        }

        if let monster = monster {
            keywords.append("vs")
            keywords.append(monster.baseName)
        }

        if let npc = npc {
            keywords.append("met")
            keywords.append(npc.name)
        }

        let narrative = turn.narration
        if narrative.lowercased().contains("defeat") || narrative.lowercased().contains("kill") {
            keywords.append("victory")
        } else if narrative.lowercased().contains("fled") || narrative.lowercased().contains("escape") {
            keywords.append("fled")
        } else if narrative.lowercased().contains("found") || narrative.lowercased().contains("discover") {
            keywords.append("found")
        } else if narrative.lowercased().contains("damage") {
            keywords.append("injured")
        }

        let keywordString = keywords.joined(separator: " ")
        encounterState.storeKeywords(keywordString)
    }

    private func buildEncounterHistory() -> String {
        let recentKeywords = encounterState.extractRecentKeywords()
        return recentKeywords.isEmpty ? "" : "Recent: \(recentKeywords)"
    }

    // MARK: - Location Management
    internal func resetAdventureState() {
        // Clear adventure progress and stats
        adventureProgress = nil
        currentAdventureXP = 0
        currentAdventureGold = 0
        currentAdventureMonsters = 0
        adventureSummary = nil
        showingAdventureSummary = false

        // Clear combat state
        combatManager.pendingMonster = nil
        combatManager.inCombat = false
        combatManager.currentMonster = nil
        combatManager.currentMonsterHP = 0

        // Clear encounter state
        pendingTrap = nil

        // Clear NPC state
        activeNPC = nil
        activeNPCTurns = 0

        // Clear inventory overflow
        needsInventoryManagement = false
        pendingLoot = []

        // Clear transaction state
        pendingTransaction = nil
    }

    func promptForNextLocation() async {
        guard var world = worldState else { return }

        // Clear adventure summary when prompting for next location
        adventureSummary = nil

        // Generate new locations if needed (completed locations are now removed, so check total count)
        if world.locations.count < 2 {
            // Check if we've hit the location cap
            if world.locations.count >= 50 {
                logger.warning("Location limit of 50 reached, not generating new locations")
            } else {
                do {
                    let newLocations = try await generateNewLocations(count: 3)
                    world.locations.append(contentsOf: newLocations)

                    // Cap total locations at 50 to prevent prompt bloat
                    if world.locations.count > 50 {
                        world.locations = Array(world.locations.prefix(50))
                        logger.info("Capped locations at 50")
                    }

                    worldState = world

                    appendModel("\n🗺️ New locations discovered!")
                    for location in newLocations {
                        appendModel("• \(location.name) (\(location.locationType.rawValue)): \(location.description)")
                    }
                } catch {
                    logger.error("Failed to generate new locations: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        // Prompt for next location (all locations in list are now available)
        let availableLocations = worldState?.locations ?? []
        if !availableLocations.isEmpty {
            appendModel("\nWhere would you like to venture next?")
            updateSuggestedActions(availableLocations.map { $0.name })
            awaitingLocationSelection = true
            saveState()
        }
    }

    private func generateNewLocations(count: Int) async throws -> [WorldLocation] {
        guard let worldSession = getSession(for: .world) else { return [] }

        let existingLocationNames = Set(worldState?.locations.map { $0.name } ?? [])
        var generatedLocations: [WorldLocation] = []
        var attempts = 0
        let maxAttempts = 10

        while generatedLocations.count < count && attempts < maxAttempts {
            attempts += 1

            // Base prompt without listing existing locations
            var prompt = "Generate \(count - generatedLocations.count) new adventure locations for this fantasy world. Ensure locations are diverse and include outdoor areas, villages, dungeons, cities, or other interesting places."

            // If we've had duplicates, explicitly mention them
            if attempts > 1 {
                let duplicates = generatedLocations.map { $0.name }.joined(separator: ", ")
                prompt += " IMPORTANT: Do NOT generate locations with these names that were already generated: \(duplicates)."
            }

            logger.debug("[World LLM - New Locations] Attempt \(attempts), Prompt length: \(prompt.count) chars")

            let response = try await worldSession.respond(to: prompt, generating: WorldState.self)

            // Post-generation verification: filter out duplicates
            for location in response.content.locations {
                if !existingLocationNames.contains(location.name) && !generatedLocations.contains(where: { $0.name == location.name }) {
                    var loc = location
                    loc.visited = false
                    loc.completed = false
                    generatedLocations.append(loc)

                    if generatedLocations.count >= count {
                        break
                    }
                } else {
                    logger.debug("[World LLM - New Locations] Duplicate detected: \(location.name), regenerating...")
                }
            }
        }

        let locationNames = generatedLocations.map { $0.name }.joined(separator: ", ")
        logger.debug("[World LLM - New Locations] Final generated: \(locationNames)")

        return generatedLocations
    }

    internal func generateAdventureSummary(progress: AdventureProgress) async {
        let notableItems = detailedInventory.suffix(5).map { $0.fullName }

        let summary = AdventureSummary(
            locationName: progress.locationName,
            questGoal: progress.questGoal,
            completionSummary: progress.adventureStory,
            encountersCompleted: progress.currentEncounter,
            totalXPGained: currentAdventureXP,
            totalGoldEarned: currentAdventureGold,
            notableItems: Array(notableItems),
            monstersDefeated: currentAdventureMonsters
        )

        adventureSummary = summary
        delegate?.engineNeedsLocationSelection(summary: summary)
    }

    // MARK: - Logging helpers
    private func appendPlayer(_ text: String) {
        log.append(LogEntry(content: String(format: L10n.playerPrefixFormat, text), isFromModel: false))
        updateLog()
    }

    func appendModel(_ text: String) {
        log.append(LogEntry(content: text, isFromModel: true))
        updateLog()
    }

    internal func appendCharacterSprite() {
        guard let character = character else { return }
        log.append(LogEntry(content: "📜 NEW CHARACTER CREATED 📜", isFromModel: true, showCharacterSprite: true, characterForSprite: character))
        updateLog()
    }

    internal func appendMonsterSprite(_ monster: MonsterDefinition) {
        log.append(LogEntry(content: "⚔️ Monster: \(monster.fullName)", isFromModel: true, showMonsterSprite: true, monsterForSprite: monster))
        updateLog()
    }
}

