import Foundation
import SwiftUI

import FoundationModels
import OSLog


@MainActor
protocol GameEngineProtocol: AnyObject {
    associatedtype LogEntryType: Identifiable & Equatable
    var log: [LogEntryType] { get }
    var character: CharacterProfile? { get }
    var adventureProgress: AdventureProgress? { get }
    var worldState: WorldState? { get }
    var currentLocation: AdventureType { get set }
    var availability: LLMGameEngine.AvailabilityState { get }
    func startNewGame(preferredType: AdventureType?, usedNames: [String]) async
    func submitPlayer(input: String) async
}

@MainActor
@Observable
final class LLMGameEngine: GameEngineProtocol {
    typealias LogEntryType = LogEntry

    // MARK: - Public State
    enum AvailabilityState: Equatable {
        case available
        case unavailable(String)
    }

    struct LogEntry: Identifiable, Equatable {
        let id: UUID
        let content: String
        let isFromModel: Bool
        let showCharacterSprite: Bool
        let characterForSprite: CharacterProfile?
        let showMonsterSprite: Bool
        let monsterForSprite: MonsterDefinition?

        init(content: String, isFromModel: Bool, showCharacterSprite: Bool = false, characterForSprite: CharacterProfile? = nil, showMonsterSprite: Bool = false, monsterForSprite: MonsterDefinition? = nil) {
            self.id = UUID()
            self.content = content
            self.isFromModel = isFromModel
            self.showCharacterSprite = showCharacterSprite
            self.characterForSprite = characterForSprite
            self.showMonsterSprite = showMonsterSprite
            self.monsterForSprite = monsterForSprite
        }

        init(id: UUID, content: String, isFromModel: Bool, showCharacterSprite: Bool = false, characterForSprite: CharacterProfile? = nil, showMonsterSprite: Bool = false, monsterForSprite: MonsterDefinition? = nil) {
            self.id = id
            self.content = content
            self.isFromModel = isFromModel
            self.showCharacterSprite = showCharacterSprite
            self.characterForSprite = characterForSprite
            self.showMonsterSprite = showMonsterSprite
            self.monsterForSprite = monsterForSprite
        }
    }

    // Live log of the adventure
    var log: [LogEntry] = []

    // Generation state
    var isGenerating: Bool = false

    // Debug info for testing
    var lastPrompt: String = ""

    // World state
    var worldState: WorldState?

    // Adventure progress
    var adventureProgress: AdventureProgress?

    var detailedInventory: [ItemDefinition] = []

    // Character and progression state
    var character: CharacterProfile?
    var currentLocation: AdventureType = .outdoor
    var currentEnvironment: String = ""

    // Encounter tracking
    private var recentEncounterTypes: [String] = []
    private let maxEncounterHistory = 5

    // Known affix tracking for prompt context
    private var knownItemAffixes: Set<String> = []
    private var knownMonsterAffixes: Set<String> = []

    // Statistics tracking
    var gameStartTime: Date?
    var adventuresCompleted: Int = 0
    var itemsCollected: Int = 0

    // Adventure tracking
    private var currentAdventureXP: Int = 0
    private var currentAdventureGold: Int = 0
    private var currentAdventureMonsters: Int = 0

    // Death state
    var characterDied: Bool = false
    var deathReport: CharacterDeathReport?

    // Current action choices for the player
    var suggestedActions: [String] = []

    // Location selection state
    var awaitingLocationSelection: Bool = false
    var adventureSummary: AdventureSummary?
    var showingAdventureSummary: Bool = false

    // Character name input state
    var awaitingCustomCharacterName: Bool = false
    var partialCharacter: CharacterProfile?

    // Inventory management state
    var needsInventoryManagement: Bool = false
    var pendingLoot: [ItemDefinition] = []
    private let maxInventorySlots = 20

    // Trading/transaction state
    struct PendingTransaction {
        let items: [String]
        let cost: Int
        let npc: NPCDefinition?
    }
    var pendingTransaction: PendingTransaction?

    // New game flow state
    var awaitingWorldContinue: Bool = false

    // Active NPC conversation tracking
    var activeNPC: NPCDefinition?
    var activeNPCTurns: Int = 0

    // Encounter keyword history for narrative continuity
    private var encounterKeywords: [String] = []
    private let maxKeywordHistory = 10

    // Model availability
    var availability: AvailabilityState = .unavailable("Checking model…")

    // MARK: - Private

    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "LLMGameEngine")
    nonisolated(unsafe) private let levelingService: LevelingServiceProtocol

    // MARK: - Managers
    private let sessionManager = SpecialistSessionManager()
    let combatManager = CombatManager()
    let affixRegistry = AffixRegistry()
    let npcRegistry = NPCRegistry()

    var inCombat: Bool { combatManager.inCombat }
    var currentMonster: MonsterDefinition? { combatManager.currentMonster }
    var currentMonsterHP: Int { combatManager.currentMonsterHP }

    // MARK: - Setup
    nonisolated init(levelingService: LevelingServiceProtocol) {
        self.levelingService = levelingService
    }

    nonisolated convenience init() {
        self.init(levelingService: DefaultLevelingService())
    }

    private func setupManagers() {
        combatManager.setGameEngine(self)
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

    private func getSession(for specialist: LLMSpecialist) -> LanguageModelSession? {
        return sessionManager.getSession(for: specialist)
    }


    // MARK: - Game Flow
    func startNewGame(preferredType: AdventureType? = nil, usedNames: [String] = []) async {
        guard case .available = availability else { return }
        logger.info("=== STARTING NEW GAME - CLEARING ALL STATE ===")

        isGenerating = true
        deleteState()

        log.removeAll()
        character = nil
        worldState = nil
        adventureProgress = nil
        detailedInventory.removeAll()
        recentEncounterTypes.removeAll()
        knownItemAffixes.removeAll()
        knownMonsterAffixes.removeAll()
        currentEnvironment = ""
        suggestedActions.removeAll()
        awaitingLocationSelection = false
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
        itemsCollected = 0
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

                // Add starting items to detailed inventory - create unique instances for each
                for _ in 0..<3 {
                    let healingPotion = ItemDefinition(
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
                    detailedInventory.append(healingPotion)
                    char.inventory.append(healingPotion.fullName)

                    let bandage = ItemDefinition(
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
                    detailedInventory.append(bandage)
                    char.inventory.append(bandage.fullName)
                }

                character = char
            } else {
                // Failed to generate unique name after max attempts
                logger.warning("[Character LLM] Failed to generate unique name after \(maxAttempts) attempts")
                partialCharacter = lastCandidate
                awaitingCustomCharacterName = true
                appendModel("\n⚠️ Unable to generate a unique character name automatically.")
                appendModel("Please enter a unique name for your character:")
                saveState()
                isGenerating = false
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
            saveState()
            isGenerating = false
            return
        } catch {
            logger.error("\(error.localizedDescription, privacy: .public)")
            appendModel(String(format: L10n.errorStartGameFormat, error.localizedDescription))
        }
        isGenerating = false
    }

    func continueNewGame(usedNames: [String] = []) async {
        guard case .available = availability else { return }

        isGenerating = true

        do {
            if awaitingWorldContinue {
                awaitingWorldContinue = false

                guard let worldSession = getSession(for: .world) else {
                    isGenerating = false
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
                    suggestedActions = world.locations.map { $0.name }
                    awaitingLocationSelection = true
                }

                saveState()
            }
        } catch {
            logger.error("\(error.localizedDescription, privacy: .public)")
            appendModel(String(format: L10n.errorStartGameFormat, error.localizedDescription))
        }

        isGenerating = false
    }

    func submitPlayer(input: String) async {
        guard case .available = availability else { return }
        guard !characterDied else { return }
        guard let adventureSession = getSession(for: .adventure), !adventureSession.isResponding else { return }

        // Truncate input to prevent prompt bloat
        let truncatedInput = input.count > 500 ? String(input.prefix(500)) : input

        isGenerating = true
        suggestedActions.removeAll()
        appendPlayer(truncatedInput)

        // Handle custom character name input
        if awaitingCustomCharacterName {
            guard var partial = partialCharacter else {
                isGenerating = false
                return
            }
            let trimmedName = truncatedInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                appendModel("Please enter a valid name.")
                isGenerating = false
                return
            }
            partial.name = trimmedName

            // Apply racial stat modifiers
            let modifiers = RaceModifiers.modifiers(for: partial.race)
            partial.attributes = modifiers.apply(to: partial.attributes)

            character = partial
            partialCharacter = nil
            awaitingCustomCharacterName = false

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

            if let world = worldState {
                appendModel("\nWhere would you like to begin your adventure?")
                suggestedActions = world.locations.map { $0.name }
                awaitingLocationSelection = true
            }

            saveState()
            isGenerating = false
            return
        }

        guard character != nil else { return }

        // Check if player is fleeing from a pending monster
        if let pendingMonster = combatManager.pendingMonster,
           !combatManager.inCombat,
           truncatedInput.lowercased().contains("flee") {
            combatManager.pendingMonster = nil
            appendModel("You attempt to flee from the \(pendingMonster.fullName)!")

            // 50% chance the monster attacks as the player flees
            let isAttacked = Bool.random()
            if isAttacked, var character = character {
                let damage = Int.random(in: 2...8)
                character.hp -= damage
                self.character = character
                appendModel("💔 The \(pendingMonster.fullName) strikes as you flee, dealing \(damage) damage!")

                if character.hp <= 0 {
                    handleCharacterDeath(monster: pendingMonster)
                    saveState()
                    isGenerating = false
                    return
                }
            } else {
                appendModel("You successfully escape!")
            }

            do {
                try await advanceScene(kind: currentLocation, playerAction: "flee from danger")
                saveState()
            } catch {
                logger.error("\(error.localizedDescription, privacy: .public)")
                appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
            }
            isGenerating = false
            return
        }

        // Handle pending transaction
        if let transaction = pendingTransaction {
            let inputLower = truncatedInput.lowercased()
            if inputLower.contains("buy") || inputLower.contains("purchase") || inputLower.contains("yes") || inputLower.contains("accept") {
                // Player wants to buy
                if var char = character {
                    if char.gold >= transaction.cost {
                        char.gold -= transaction.cost
                        for item in transaction.items {
                            char.inventory.append(item)
                        }
                        self.character = char
                        appendModel("💸 Paid \(transaction.cost) gold")
                        for item in transaction.items {
                            appendModel("📦 Acquired: \(item)")
                        }
                        pendingTransaction = nil
                        saveState()
                        isGenerating = false
                        return
                    } else {
                        appendModel("⚠️ Not enough gold! Need \(transaction.cost) but only have \(char.gold)")
                        appendModel("You move on...")
                        pendingTransaction = nil
                        // Continue to next encounter instead of stopping
                        do {
                            try await advanceScene(kind: currentLocation, playerAction: "continue exploring")
                            saveState()
                        } catch {
                            logger.error("\(error.localizedDescription, privacy: .public)")
                            appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
                        }
                        isGenerating = false
                        return
                    }
                }
            } else if inputLower.contains("decline") || inputLower.contains("no") || inputLower.contains("refuse") || inputLower.contains("pass") {
                // Player declines
                appendModel("You decline the offer.")
                pendingTransaction = nil
                // Continue to next encounter
                do {
                    try await advanceScene(kind: currentLocation, playerAction: "continue exploring")
                    saveState()
                } catch {
                    logger.error("\(error.localizedDescription, privacy: .public)")
                    appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
                }
                isGenerating = false
                return
            }
            // If action doesn't match buy/decline keywords, clear transaction and continue with the action
            pendingTransaction = nil
        }

        // Check if player is initiating combat with a pending monster
        if let pendingMonster = combatManager.pendingMonster,
           !combatManager.inCombat,
           (truncatedInput.lowercased().contains("attack") || truncatedInput.lowercased().contains("fight") || truncatedInput.lowercased().contains("engage")) {
            combatManager.enterCombat(with: pendingMonster)
            saveState()
            isGenerating = false
            return
        }

        // If there's a pending monster and player chose a non-combat action, evaluate if action prevents attack
        if let pendingMonster = combatManager.pendingMonster, !combatManager.inCombat {
            let monsterAttacks = await shouldMonsterAttack(monster: pendingMonster, playerAction: truncatedInput)

            if monsterAttacks, var character = character {
                let damage = Int.random(in: 3...10)
                character.hp -= damage
                self.character = character
                appendModel("💔 The \(pendingMonster.fullName) attacks while you're distracted, dealing \(damage) damage!")

                if character.hp <= 0 {
                    handleCharacterDeath(monster: pendingMonster)
                    combatManager.pendingMonster = nil
                    saveState()
                    isGenerating = false
                    return
                }
                // Monster remains after attacking - player can still choose to fight or flee next turn
            } else {
                // Monster doesn't attack - clear it and player's action succeeds
                combatManager.pendingMonster = nil
                appendModel("Your action successfully prevents the \(pendingMonster.fullName) from attacking!")
            }
        }

        // Handle active combat actions
        if combatManager.inCombat {
            let inputLower = truncatedInput.lowercased()

            // Capture combat state for logging
            if let monster = combatManager.currentMonster, let char = character {
                lastPrompt = "Combat State: \(char.name) (HP: \(char.hp)/\(char.maxHP)) vs \(monster.fullName) (HP: \(combatManager.currentMonsterHP)/\(monster.hp))\nPlayer action: \(truncatedInput)"
            }

            if inputLower.contains("flee") || inputLower.contains("run") || inputLower.contains("escape") {
                let success = combatManager.fleeCombat()
                if success {
                    do {
                        try await advanceScene(kind: currentLocation, playerAction: "fled from combat")
                        saveState()
                    } catch {
                        logger.error("\(error.localizedDescription, privacy: .public)")
                        appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
                    }
                }
                saveState()
                isGenerating = false
                return
            } else if inputLower.contains("surrender") || inputLower.contains("give up") {
                combatManager.surrenderCombat()
                saveState()
                isGenerating = false
                return
            } else {
                combatManager.performCombatAction(truncatedInput)
                saveState()
                isGenerating = false
                return
            }
        }

        // Handle location selection
        if awaitingLocationSelection {
            if let world = worldState, let selectedLocation = world.locations.first(where: { $0.name.lowercased() == truncatedInput.lowercased() || truncatedInput.lowercased().contains($0.name.lowercased()) }) {
                currentLocation = selectedLocation.locationType
                awaitingLocationSelection = false
                showingAdventureSummary = false
                adventureSummary = nil

                // Reset adventure tracking for new adventure
                currentAdventureXP = 0
                currentAdventureGold = 0
                currentAdventureMonsters = 0

                // Clear any pending monsters/NPCs from previous adventure
                combatManager.pendingMonster = nil
                activeNPC = nil
                activeNPCTurns = 0

                // Mark location as visited
                if var world = worldState {
                    if let index = world.locations.firstIndex(where: { $0.name == selectedLocation.name }) {
                        world.locations[index].visited = true
                    }
                    worldState = world
                }

                do {
                    try await advanceScene(kind: currentLocation, playerAction: nil)
                    saveState()
                } catch {
                    logger.error("\(error.localizedDescription, privacy: .public)")
                    appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
                }
                isGenerating = false
                return
            } else {
                appendModel("Please choose one of the available locations.")
                if let world = worldState {
                    suggestedActions = world.locations.map { $0.name }
                }
                isGenerating = false
                return
            }
        }

        do {
            try await advanceScene(kind: currentLocation, playerAction: truncatedInput)
            saveState()
        } catch {
            logger.error("\(error.localizedDescription, privacy: .public)")
            appendModel(String(format: L10n.errorGenericFormat, error.localizedDescription))
        }
        isGenerating = false
    }

    func apply(turn: AdventureTurn, encounter: EncounterDetails?, rewards: ProgressionRewards?, loot: [ItemDefinition], monster: MonsterDefinition?, npc: NPCDefinition?) async {
        if let encounterType = encounter?.encounterType {
            trackEncounter(encounterType)
        }

        storeEncounterKeywords(turn: turn, encounter: encounter, monster: monster, npc: npc)

        if let progress = turn.adventureProgress {
            // Don't trust LLM's encounter counter - increment it ourselves
            if var currentProgress = adventureProgress {
                // Keep our counter, but update narrative fields from LLM
                currentProgress.currentEncounter += 1
                currentProgress.questGoal = progress.questGoal
                currentProgress.adventureStory = progress.adventureStory
                currentProgress.completed = progress.completed
                adventureProgress = currentProgress
            } else {
                // First encounter - accept LLM's progress but clear its summaries (we'll generate our own)
                var initialProgress = progress
                initialProgress.encounterSummaries = []
                adventureProgress = initialProgress

                // Display quest goal before first encounter
                appendModel("\n🎯 Quest: \(progress.questGoal)")
                appendModel("📍 Location: \(progress.locationName)")
                appendModel("")
            }

            let summary = generateEncounterSummary(
                narrative: turn.narration,
                encounterType: encounter?.encounterType ?? "unknown",
                monster: monster,
                npc: npc
            )
            adventureProgress?.encounterSummaries.append(summary)

            // Check if player action completes the quest in final encounter
            if let finalProgress = adventureProgress, finalProgress.isFinalEncounter {
                if finalProgress.completed {
                    // Check if character is alive before awarding quest completion
                    guard let char = character, char.hp > 0 else {
                        // Character died - quest cannot be completed
                        logger.warning("[Quest] Character died during final encounter - quest completion denied")
                        var failedProgress = finalProgress
                        failedProgress.completed = false
                        adventureProgress = failedProgress
                        return
                    }

                    // LLM marked quest as completed and character is alive - success!
                    appendModel("\n✅ Adventure Complete: \(finalProgress.locationName)")
                    adventuresCompleted += 1

                    // Mark location as completed
                    if var world = worldState {
                        if let index = world.locations.firstIndex(where: { $0.name == finalProgress.locationName }) {
                            world.locations[index].completed = true
                            world.locations[index].visited = true
                        }
                        worldState = world
                    }

                    // Clear any pending monsters/NPCs since adventure is complete
                    combatManager.pendingMonster = nil
                    activeNPC = nil
                    activeNPCTurns = 0

                    // Generate adventure summary
                    await generateAdventureSummary(progress: finalProgress)
                }
            }
        }

        if let monster = monster {
            // Store monster as pending - don't enter combat automatically
            // Player must choose to attack via their action
            combatManager.pendingMonster = monster
            appendMonsterSprite(monster)
            appendModel("HP: \(monster.hp) | Defense: \(monster.defense)")
            if !monster.abilities.isEmpty {
                appendModel("Abilities: \(monster.abilities.prefix(3).joined(separator: ", "))")
            }

            // Override suggested actions to give player combat choices
            var combatActions = ["Attack the \(monster.fullName)", "Flee"]
            // Keep one non-combat action if available (filter out any combat-triggering words)
            let nonCombatActions = turn.suggestedActions.filter { action in
                let lowercased = action.lowercased()
                return !lowercased.contains("attack") &&
                       !lowercased.contains("fight") &&
                       !lowercased.contains("engage") &&
                       !lowercased.contains("strike") &&
                       !lowercased.contains("hit")
            }
            if let firstNonCombatAction = nonCombatActions.first {
                combatActions.insert(firstNonCombatAction, at: 1)
            }
            self.suggestedActions = combatActions
        } else {
            self.suggestedActions = turn.suggestedActions
        }

        if let npc = npc {
            appendModel("\n💬 NPC: \(npc.name) the \(npc.occupation)")
            if npc.interactionCount > 0 {
                appendModel("(You've met \(npc.interactionCount) time\(npc.interactionCount == 1 ? "" : "s") before)")
            }
        }

        // Don't apply rewards if a monster is pending - rewards only apply after player chooses action
        // This prevents damage from being applied when monster first appears
        let shouldApplyRewards = monster == nil
        let encounterType = encounter?.encounterType.lowercased() ?? ""
        let isSocialEncounter = encounterType == "social"

        if shouldApplyRewards {
            if isSocialEncounter {
                let clampedXP = min(5, max(2, rewards?.xpGain ?? 0))
                if clampedXP > 0, var c = self.character {
                    currentAdventureXP += clampedXP
                    let outcome = levelingService.applyXPGain(clampedXP, to: &c)
                    self.character = c
                    if outcome.didLevelUp {
                        appendModel(outcome.logLine)
                        if outcome.needsNewAbility {
                            await generateLevelReward(for: c.className, level: outcome.newLevel ?? 1)
                        }
                    } else {
                        appendModel("✨ Gained \(clampedXP) XP!")
                    }
                }
            } else if let xpGain = rewards?.xpGain {
                currentAdventureXP += xpGain
                if var c = self.character {
                    let outcome = levelingService.applyXPGain(xpGain, to: &c)
                    self.character = c
                    if outcome.didLevelUp {
                        appendModel(outcome.logLine)
                        if outcome.needsNewAbility {
                            await generateLevelReward(for: c.className, level: outcome.newLevel ?? 1)
                        }
                    }
                }
            }
        }

        if shouldApplyRewards, !isSocialEncounter, let hpDelta = rewards?.hpDelta {
            if var char = self.character {
                char.hp += hpDelta
                char.hp = min(char.hp, char.maxHP)
                self.character = char
            }
            if hpDelta < 0 {
                appendModel("💔 Took \(abs(hpDelta)) damage!")
                checkDeath()
                // Stop processing if character died
                if characterDied {
                    return
                }
            } else if hpDelta > 0 {
                appendModel("❤️ Healed \(hpDelta) HP!")
            }
        } else if shouldApplyRewards {
            // Natural HP regeneration: +1 HP per encounter if no damage taken and below max HP
            if var char = self.character, char.hp < char.maxHP, rewards?.hpDelta == nil || rewards?.hpDelta == 0 {
                char.hp += 1
                char.hp = min(char.hp, char.maxHP)
                self.character = char
                appendModel("❤️‍🩹 Regenerated 1 HP")
            }
        }

        if shouldApplyRewards, !isSocialEncounter, let gold = rewards?.goldGain, gold > 0 {
            currentAdventureGold += gold
            self.character?.gold += gold
            appendModel("💰 Found \(gold) gold!")
        }

        // Check if NPC is offering items for purchase - make it pending instead of auto-applying
        if let items = turn.itemsAcquired, !items.isEmpty, let goldCost = turn.goldSpent, goldCost > 0 {
            // This is a purchase offer - make it pending
            pendingTransaction = PendingTransaction(items: items, cost: goldCost, npc: npc)
            appendModel("\n💰 Offer: \(items.joined(separator: ", ")) for \(goldCost) gold")

            // Override suggested actions to give player choice
            var transactionActions = ["Buy the items", "Decline the offer"]
            // Keep one other action if available
            if let firstOther = turn.suggestedActions.first {
                transactionActions.insert(firstOther, at: 1)
            }
            self.suggestedActions = transactionActions
        } else {
            // Free items (gifts, found items) - apply immediately
            if let items = turn.itemsAcquired, !items.isEmpty {
                for item in items {
                    self.character?.inventory.append(item)
                    appendModel("📦 Acquired: \(item)")
                }
            }
        }

        if shouldApplyRewards, !loot.isEmpty {
            // Check if adding items would exceed inventory limit
            let totalItems = detailedInventory.count + loot.count
            if totalItems > maxInventorySlots {
                // Trigger inventory management
                pendingLoot = loot
                needsInventoryManagement = true
                appendModel("⚠️ Inventory full! You need to make room for new items.")
            } else {
                // Add items normally
                for item in loot {
                    detailedInventory.append(item)
                    var inventory = Set(self.character?.inventory ?? [])
                    inventory.insert(item.fullName)
                    self.character?.inventory = Array(inventory)
                    appendModel("✨ Obtained: \(item.fullName) (\(item.rarity))")
                    itemsCollected += 1
                }
            }
        }

        if let environment = turn.currentEnvironment {
            self.currentEnvironment = environment
        }

        appendModel(turn.narration)
        if let prompt = turn.playerPrompt, !prompt.isEmpty {
            appendModel(prompt)
        }
    }

    private func trackEncounter(_ type: String) {
        recentEncounterTypes.append(type)
        if recentEncounterTypes.count > maxEncounterHistory {
            recentEncounterTypes.removeFirst()
        }
    }

    private func generateLevelReward(for className: String, level: Int) async {
        guard var character = self.character else { return }

        let rewardType: LLMSpecialist
        let rewardList: String

        switch className.lowercased() {
        case "mage", "necromancer":
            rewardType = .spells
            rewardList = className.lowercased() == "necromancer" ? "death spell" : "arcane spell"
        case "healer", "paladin":
            rewardType = .prayers
            rewardList = "divine prayer"
        case "druid":
            rewardType = .spells
            rewardList = "nature spell"
        default:
            rewardType = .abilities
            rewardList = "class ability"
        }

        guard let session = getSession(for: rewardType) else { return }

        let existingRewards = Set(character.abilities + character.spells)
        var attempts = 0
        let maxAttempts = 5

        do {
            while attempts < maxAttempts {
                attempts += 1

                // Base prompt without listing all existing abilities/spells
                var prompt = "Character: Level \(level) \(className). Generate a single new \(rewardList). Provide only the name of the \(rewardList)."

                if !existingRewards.isEmpty {
                    let recentRewards = Array(existingRewards.prefix(5)).joined(separator: ", ")
                    prompt += " Already has: \(recentRewards)."
                }

                prompt += " Generate a unique \(rewardList) appropriate for this level and class."

                // If we've had duplicates, explicitly mention them
                if attempts > 1 {
                    prompt += " AVOID duplicates."
                }

                logger.debug("[\(rewardType.rawValue.capitalized) LLM] Attempt \(attempts), Prompt length: \(prompt.count) chars")

                let response = try await session.respond(to: prompt, generating: LevelReward.self)
                let reward = response.content.name

                // Post-generation verification
                if !existingRewards.contains(reward) {
                    logger.debug("[\(rewardType.rawValue.capitalized) LLM] Generated unique reward: \(reward)")

                    switch rewardType {
                    case .spells:
                        character.spells.append(reward)
                        appendModel("📜 New Spell Learned: \(reward)")
                    case .prayers:
                        character.spells.append(reward)
                        appendModel("✨ New Prayer Granted: \(reward)")
                    case .abilities:
                        character.abilities.append(reward)
                        appendModel("⚡️ New Ability Gained: \(reward)")
                    default:
                        break
                    }

                    self.character = character
                    saveState()
                    return
                } else {
                    logger.debug("[\(rewardType.rawValue.capitalized) LLM] Duplicate reward '\(reward)' detected, regenerating...")
                }
            }

            // Fallback: if all attempts failed, use the last generated reward anyway
            logger.warning("[\(rewardType.rawValue.capitalized) LLM] Failed to generate unique reward after \(maxAttempts) attempts")
        } catch {
            logger.error("Failed to generate level reward: \(error.localizedDescription, privacy: .public)")
        }
    }


    private func generateMonster(for encounter: EncounterDetails, characterLevel: Int, location: String) async throws -> MonsterDefinition? {
        guard let monsterSession = getSession(for: .monsters) else { return nil }

        let baseMonsters = MonsterDatabase.allMonsters.filter { monster in
            if characterLevel <= 3 { return monster.baseHP <= 20 }
            else if characterLevel <= 7 { return monster.baseHP > 15 && monster.baseHP <= 60 }
            else if characterLevel <= 12 { return monster.baseHP > 45 && monster.baseHP <= 120 }
            else { return monster.baseHP > 80 }
        }

        let randomBase = baseMonsters.randomElement() ?? MonsterDatabase.allMonsters[0]
        let knownAffixList = Array(knownMonsterAffixes.suffix(10)).joined(separator: ", ")

        let prompt = "Base monster: \(randomBase.name) (\(randomBase.description)). Character level: \(characterLevel). Difficulty: \(encounter.difficulty). Location: \(location). Known affixes: \(knownAffixList.isEmpty ? "none yet" : knownAffixList). Avoid repeating known affixes if possible. Generate a modified monster with appropriate scaling and optional affixes."
        logger.debug("[Monster LLM] Prompt length: \(prompt.count) chars")

        let response = try await monsterSession.respond(to: prompt, generating: MonsterDefinition.self)
        logger.debug("[Monster LLM] Generated: \(response.content.fullName)")
        let monster = response.content

        if let prefix = monster.prefix {
            affixRegistry.registerMonsterAffix(prefix)
            knownMonsterAffixes.insert(prefix.name)
        }
        if let suffix = monster.suffix {
            affixRegistry.registerMonsterAffix(suffix)
            knownMonsterAffixes.insert(suffix.name)
        }

        return monster
    }

    private func generateOrRetrieveNPC(for location: String, encounter: EncounterDetails) async throws -> NPCDefinition? {
        guard let npcSession = getSession(for: .npc) else { return nil }

        let existingNPCs = npcRegistry.getNPCs(atLocation: location)

        if !existingNPCs.isEmpty && Bool.random() {
            guard var npc = existingNPCs.randomElement() else { return nil }
            npc.interactionCount += 1
            npcRegistry.registerNPC(npc, location: location)
            return npc
        }

        let existingNPCNames = Set(existingNPCs.map { $0.name })
        var attempts = 0
        let maxAttempts = 5

        while attempts < maxAttempts {
            attempts += 1

            // Base prompt without listing all existing NPCs
            var prompt = "Location: \(location). Encounter difficulty: \(encounter.difficulty). Create a new NPC appropriate for this location."

            // If we've had duplicates, explicitly mention them
            if attempts > 1 {
                prompt += " IMPORTANT: The NPC name must NOT be any of these already existing NPCs at this location: \(existingNPCNames.joined(separator: ", "))."
            }

            logger.debug("[NPC LLM] Attempt \(attempts), Prompt length: \(prompt.count) chars")

            let response = try await npcSession.respond(to: prompt, generating: NPCDefinition.self)
            let candidate = response.content

            // Post-generation verification
            if !existingNPCNames.contains(candidate.name) {
                logger.debug("[NPC LLM] Generated unique NPC: \(candidate.name)")
                var npc = candidate
                npc.location = location
                npc.interactionCount = 0
                npcRegistry.registerNPC(npc, location: location)
                return npc
            } else {
                logger.debug("[NPC LLM] Duplicate NPC name '\(candidate.name)' detected, regenerating...")
            }
        }

        // Fallback: use the last generated NPC even if duplicate
        logger.warning("[NPC LLM] Failed to generate unique NPC after \(maxAttempts) attempts, using last generated")
        var npc = try await npcSession.respond(to: "Location: \(location). Create a new NPC.", generating: NPCDefinition.self).content
        npc.location = location
        npc.interactionCount = 0
        npcRegistry.registerNPC(npc, location: location)
        return npc
    }

    private func determineItemRarity(difficulty: String, characterLevel: Int) -> String {
        // Rarity probabilities:
        // 1% legendary, 5% epic, 10% rare, 30% uncommon, 54% common
        let roll = Int.random(in: 1...100)

        // Boss encounters get bonus to rarity
        let isBoss = difficulty.lowercased() == "boss"
        let isHard = difficulty.lowercased() == "hard"

        if isBoss {
            // Boss: better odds for high rarity
            if roll <= 5 { return "legendary" }      // 5% (was 1%)
            if roll <= 20 { return "epic" }          // 15% (was 5%)
            if roll <= 45 { return "rare" }          // 25% (was 10%)
            if roll <= 75 { return "uncommon" }      // 30% (same)
            return "common"                          // 25% (was 54%)
        } else if isHard {
            // Hard: slightly better odds
            if roll <= 2 { return "legendary" }      // 2%
            if roll <= 10 { return "epic" }          // 8%
            if roll <= 25 { return "rare" }          // 15%
            if roll <= 55 { return "uncommon" }      // 30%
            return "common"                          // 45%
        } else {
            // Normal/easy: standard odds
            if roll <= 1 { return "legendary" }      // 1%
            if roll <= 6 { return "epic" }           // 5%
            if roll <= 16 { return "rare" }          // 10%
            if roll <= 46 { return "uncommon" }      // 30%
            return "common"                          // 54%
        }
    }

    private func generateLoot(count: Int, difficulty: String, characterLevel: Int, characterClass: String) async throws -> [ItemDefinition] {
        guard let equipmentSession = getSession(for: .equipment) else { return [] }

        var items: [ItemDefinition] = []
        let knownAffixList = Array(knownItemAffixes.suffix(10)).joined(separator: ", ")

        var existingItemNames = Set<String>()
        for item in detailedInventory {
            existingItemNames.insert(item.fullName)
        }

        for i in 0..<count {
            // Determine rarity before generating item
            let rarity = determineItemRarity(difficulty: difficulty, characterLevel: characterLevel)
            logger.debug("[Equipment LLM] Pre-determined rarity: \(rarity)")

            var maxAttempts = 3
            var item: ItemDefinition?

            while maxAttempts > 0 {
                let prompt = "Character level: \(characterLevel). Class: \(characterClass). Difficulty: \(difficulty). Rarity: \(rarity). Known affixes: \(knownAffixList.isEmpty ? "none yet" : knownAffixList). Avoid repeating known affixes if possible. Generate one \(rarity) rarity magical item appropriate for this class and level. CRITICAL: If rarity is epic or legendary, the item MUST have prefix and/or suffix affixes - NEVER generate plain items like 'Dagger' or 'Staff' for epic/legendary rarity."
                logger.debug("[Equipment LLM] Item \(i+1)/\(count) Prompt length: \(prompt.count) chars")

                do {
                    let response = try await equipmentSession.respond(to: prompt, generating: ItemDefinition.self)
                    var candidate = response.content
                    logger.debug("[Equipment LLM] Item \(i+1)/\(count) Generated: \(candidate.fullName)")

                    // Force rarity to match pre-determined value if LLM gave wrong rarity
                    if candidate.rarity.lowercased() != rarity.lowercased() {
                        logger.warning("[Equipment LLM] Rarity mismatch: expected \(rarity), got \(candidate.rarity). Correcting...")
                        candidate.rarity = rarity
                    }

                    // Check for duplicate item name
                    if existingItemNames.contains(candidate.fullName) {
                        logger.warning("[Equipment LLM] Duplicate item detected: \(candidate.fullName), regenerating...")
                        maxAttempts -= 1
                        continue
                    }

                    // Check for missing affixes on epic/legendary items only
                    // Common, uncommon, and rare can be plain items
                    let rarityLower = candidate.rarity.lowercased()
                    if (rarityLower == "epic" || rarityLower == "legendary") && candidate.prefix == nil && candidate.suffix == nil {
                        // Check if baseName contains common affix words (e.g., "Shadow Dagger", "Necrostaff")
                        let baseNameLower = candidate.baseName.lowercased()
                        let hasEmbeddedAffix = baseNameLower.contains("shadow") ||
                                               baseNameLower.contains("spectral") ||
                                               baseNameLower.contains("dark") ||
                                               baseNameLower.contains("light") ||
                                               baseNameLower.contains("necro") ||
                                               baseNameLower.contains("holy") ||
                                               baseNameLower.contains("fire") ||
                                               baseNameLower.contains("ice") ||
                                               baseNameLower.split(separator: " ").count > 1

                        if !hasEmbeddedAffix {
                            logger.warning("[Equipment LLM] Epic/Legendary item missing affixes: \(candidate.fullName), regenerating...")
                            maxAttempts -= 1
                            continue
                        } else {
                            logger.info("[Equipment LLM] Item has embedded affix in baseName: \(candidate.baseName)")
                        }
                    }

                    item = candidate
                    break
                } catch {
                    logger.error("[Equipment LLM] Generation failed: \(error.localizedDescription)")
                    maxAttempts -= 1
                    if maxAttempts <= 0 {
                        logger.error("[Equipment LLM] Max attempts reached, skipping item")
                    }
                }
            }

            // Use the item even if it has issues after max attempts
            if let finalItem = item {
                existingItemNames.insert(finalItem.fullName)

                if let prefix = finalItem.prefix {
                    affixRegistry.registerItemAffix(prefix)
                    knownItemAffixes.insert(prefix.name)
                }
                if let suffix = finalItem.suffix {
                    affixRegistry.registerItemAffix(suffix)
                    knownItemAffixes.insert(suffix.name)
                }

                items.append(finalItem)
            } else {
                logger.warning("[Equipment LLM] Failed to generate item \(i+1)/\(count) after \(3) attempts")
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
                        if currentInventoryCount + loot.count > maxInventorySlots {
                            pendingLoot = loot
                            needsInventoryManagement = true
                            appendModel("⚠️ Inventory full! You need to make room for new items.")
                        } else {
                            for item in loot {
                                detailedInventory.append(item)
                                var inventory = Set(character?.inventory ?? [])
                                inventory.insert(item.fullName)
                                character?.inventory = Array(inventory)
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

        // Remove from inventory (only one instance)
        if let index = char.inventory.firstIndex(of: itemName) {
            char.inventory.remove(at: index)
        }
        if let index = detailedInventory.firstIndex(where: { $0.fullName == itemName || $0.baseName == itemName }) {
            detailedInventory.remove(at: index)
        }

        character = char
        saveState()
        return true
    }

    func finalizeInventorySelection(_ selectedItems: [ItemDefinition]) {
        detailedInventory = selectedItems
        var inventory = Set<String>()
        for item in selectedItems {
            inventory.insert(item.fullName)
        }
        character?.inventory = Array(inventory)

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

            combatManager.reset()
            appendModel("\n💀 You have fallen...")
        }
    }

    private func handleCharacterDeath(monster: MonsterDefinition) {
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

        combatManager.reset()
        appendModel("\n💀 You have fallen...")
    }

    private func shouldMonsterAttack(monster: MonsterDefinition, playerAction: String) async -> Bool {
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
        return recentEncounterTypes.last
    }

    private func countSinceLastTrap() -> Int? {
        if let idx = recentEncounterTypes.lastIndex(of: "trap") {
            return recentEncounterTypes.count - 1 - idx
        }
        return nil
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
        if encounter.encounterType == "combat", lastEncounterType() == "combat" {
            // Coerce to exploration to break up combat streaks
            encounter = EncounterDetails(encounterType: "exploration", difficulty: encounter.difficulty)
        }
        // Prevent consecutive social encounters (too many NPCs)
        if encounter.encounterType == "social", lastEncounterType() == "social" {
            // Coerce to exploration to break up NPC streaks
            encounter = EncounterDetails(encounterType: "exploration", difficulty: encounter.difficulty)
        }
        // Enforce 3+ non-trap encounters between traps
        if encounter.encounterType == "trap" {
            let sinceTrap = countSinceLastTrap() ?? Int.max
            if sinceTrap < 3 {
                encounter = EncounterDetails(encounterType: "exploration", difficulty: encounter.difficulty)
            }
        }
    }

    private func sanitizeNarration(_ text: String, for encounterType: String?) -> String {
        // Do not allow combat resolution in narrative. Replace problematic verbs with neutral phrasing.
        let forbidden = ["defeat", "defeated", "kill", "killed", "slay", "slain", "strike", "struck", "smite", "smitten", "crush", "crushed", "stab", "stabbed", "shoot", "shot", "damage", "wound", "wounded"]
        var sanitized = text
        if let type = encounterType, type == "combat" || type == "final" {
            for word in forbidden {
                sanitized = sanitized.replacingOccurrences(of: word, with: "confront", options: [.caseInsensitive, .regularExpression])
            }
        }
        return sanitized
    }

    private func smartTruncatePrompt(_ prompt: String, maxLength: Int) -> String {
        if prompt.count <= maxLength {
            return prompt
        }

        // Strategy: Preserve critical sections, compress narrative sections
        // Priority order (must keep):
        // 1. Core context (location, action, encounter, character stats)
        // 2. Critical instructions (QUEST STAGE, CRITICAL, quest goal)
        // 3. Recent context (last encounter summary)
        // Lower priority (can compress):
        // 4. Adventure history (compress heavily)
        // 5. Full encounter history (compress to count)

        let lines = prompt.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []
        var currentLength = 0

        // Pass 1: Identify and preserve critical sections
        for line in lines {
            let lineLower = line.lowercased()
            let isCritical = lineLower.contains("critical") ||
                            lineLower.contains("quest stage") ||
                            lineLower.contains("quest:") ||
                            lineLower.contains("encounter:") ||
                            lineLower.contains("character:") ||
                            lineLower.contains("location:")

            if isCritical {
                // Always include critical lines
                result.append(line)
                currentLength += line.count + 1
            } else if lineLower.contains("adventure so far:") {
                // Compress adventure history to keywords
                if let colonIndex = line.firstIndex(of: ":") {
                    let history = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    let compressed = compressNarrative(history, maxLength: 150)
                    let compressedLine = "Adventure so far: \(compressed)"
                    result.append(compressedLine)
                    currentLength += compressedLine.count + 1
                } else {
                    result.append(line)
                    currentLength += line.count + 1
                }
            } else if lineLower.contains("encounter history:") {
                // Keep encounter history but compress if too long
                if line.count > 200 {
                    let types = line.components(separatedBy: ": ").dropFirst().joined(separator: ": ")
                    let encounters = types.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    let compressed = "Encounter History: \(encounters.count) encounters (\(encounters.suffix(3).joined(separator: ", ")))"
                    result.append(compressed)
                    currentLength += compressed.count + 1
                } else {
                    result.append(line)
                    currentLength += line.count + 1
                }
            } else {
                // Non-critical line - include if we have room
                if currentLength + line.count + 1 <= maxLength {
                    result.append(line)
                    currentLength += line.count + 1
                }
            }
        }

        let truncated = result.joined(separator: "\n")

        // If still too long, do final hard truncate but preserve last 500 chars (critical instructions)
        if truncated.count > maxLength {
            let preserveEnd = 500
            let takeFromStart = maxLength - preserveEnd - 20 // 20 for " [...] "
            if takeFromStart > 0 {
                let start = String(truncated.prefix(takeFromStart))
                let end = String(truncated.suffix(preserveEnd))
                return start + " [...] " + end
            } else {
                return String(truncated.suffix(maxLength))
            }
        }

        return truncated
    }

    private func compressNarrative(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }

        // Extract key information: verbs, nouns, locations, names
        // Remove filler words and elaborate descriptions
        let fillerWords = ["the", "a", "an", "is", "was", "were", "been", "being", "have", "has", "had",
                          "do", "does", "did", "will", "would", "should", "could", "may", "might",
                          "very", "quite", "rather", "really", "just", "only", "even",
                          "beneath", "feeling", "senses", "attuned", "whispers"]

        // Split into sentences, keep keywords from each
        let sentences = text.components(separatedBy: "→").map { $0.trimmingCharacters(in: .whitespaces) }
        var keywords: [String] = []

        for sentence in sentences {
            let words = sentence.split(separator: " ").map(String.init)
            let important = words.filter { word in
                let clean = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
                return !fillerWords.contains(clean) && clean.count > 3
            }
            keywords.append(contentsOf: important.prefix(3)) // Keep up to 3 keywords per sentence
        }

        let compressed = keywords.joined(separator: " ")
        return String(compressed.prefix(maxLength))
    }

    private func advanceScene(kind: AdventureType, playerAction: String?) async throws {
        guard let adventureSession = getSession(for: .adventure),
              let encounterSession = getSession(for: .encounter),
              let progressionSession = getSession(for: .progression) else { return }

        // Check if quest is already completed - if so, don't generate new encounters
        if let progress = adventureProgress, progress.completed {
            await promptForNextLocation()
            return
        }

        // Check if quest has already failed - if so, don't generate new encounters
        if let progress = adventureProgress, progress.isFinalEncounter {
            let encountersOverLimit = progress.currentEncounter - progress.totalEncounters
            if encountersOverLimit >= 3 && !progress.completed {
                // Quest has failed - show summary and prompt for next location
                appendModel("\n❌ Quest Failed: You were unable to complete '\(progress.questGoal)' in time.")
                appendModel("The opportunity has passed...")

                if var world = worldState {
                    if let index = world.locations.firstIndex(where: { $0.name == progress.locationName }) {
                        world.locations[index].visited = true
                        world.locations[index].completed = false
                    }
                    worldState = world
                }

                let failedSummary = AdventureSummary(
                    locationName: progress.locationName,
                    questGoal: progress.questGoal,
                    completionSummary: "Quest failed - objective not completed in time",
                    encountersCompleted: progress.currentEncounter,
                    totalXPGained: currentAdventureXP,
                    totalGoldEarned: currentAdventureGold,
                    notableItems: Array(detailedInventory.suffix(5).map { $0.fullName }),
                    monstersDefeated: currentAdventureMonsters
                )
                adventureSummary = failedSummary
                showingAdventureSummary = true
                return
            }
        }

        sessionManager.incrementTurnCount()
        sessionManager.resetIfNeeded()

        let actionLine = playerAction.map { "Player action: \($0)" } ?? "Begin scene"
        let location = kind.rawValue
        let contextSummary = buildContextSummary()
        let charLevel = levelingService.level(forXP: character?.xp ?? 0)

        var encounter: EncounterDetails
        var monster: MonsterDefinition?
        var npc: NPCDefinition?

        // Check if continuing an active NPC conversation
        let playerActionLower = (playerAction ?? "").lowercased()

        // Check if player specifically references the NPC by name
        // Only continue conversation if explicitly mentioning NPC name or using direct speech verbs
        let isReferencingNPC = activeNPC != nil && (
            playerActionLower.contains(activeNPC!.name.lowercased()) ||
            (playerActionLower.contains("speak to") ||
             playerActionLower.contains("talk to") ||
             playerActionLower.contains("ask the") ||
             playerActionLower.contains("tell the"))
        )

        // Continue conversation only if: NPC active, referenced by player, and under turn limit
        let isContinuingConversation = activeNPC != nil && isReferencingNPC && activeNPCTurns < 2

        if isContinuingConversation {
            // Continue existing social encounter with same NPC
            encounter = EncounterDetails(encounterType: "social", difficulty: "normal")
            npc = activeNPC
            activeNPCTurns += 1
            logger.debug("[Encounter] Continuing conversation with \(npc?.name ?? "NPC") (turn \(self.activeNPCTurns))")
        } else {
            // Clear active NPC if turn limit reached or not referenced
            if activeNPC != nil && (!isReferencingNPC || activeNPCTurns >= 2) {
                logger.debug("[Encounter] Ending conversation with \(self.activeNPC?.name ?? "NPC")")
                activeNPC = nil
                activeNPCTurns = 0
            }

            var encounterPrompt = "Character level \(charLevel). Location: \(location). Recent encounters: \(recentEncounterTypes.joined(separator: ", ")). Adventure progress: \(adventureProgress?.progress ?? "0/10")."
            if let adventure = adventureProgress {
                encounterPrompt += " Quest: \(adventure.questGoal)."
                if adventure.isFinalEncounter {
                    // Analyze quest type to determine if final encounter should be combat or non-combat
                    let questLower = adventure.questGoal.lowercased()
                    if questLower.contains("find") || questLower.contains("retrieve") || questLower.contains("locate") || questLower.contains("discover") {
                        // Retrieval quest - present artifact/item
                        encounterPrompt += " This is the FINAL encounter - use 'final' type (non-combat) to present the artifact/objective for retrieval."
                    } else if questLower.contains("defeat") || questLower.contains("kill") || questLower.contains("destroy") || questLower.contains("stop") {
                        // Combat quest - boss fight
                        encounterPrompt += " This is the FINAL encounter - use 'combat' type with 'boss' difficulty to present the enemy."
                    } else if questLower.contains("escort") || questLower.contains("protect") || questLower.contains("guide") {
                        // Escort quest - reach destination safely or defend against final threat
                        encounterPrompt += " This is the FINAL encounter - use 'final' type to reach the destination, or 'combat' with 'hard' difficulty if there's a final threat to overcome."
                    } else if questLower.contains("investigate") || questLower.contains("solve") || questLower.contains("uncover") {
                        // Investigation quest - solve the mystery
                        encounterPrompt += " This is the FINAL encounter - use 'final' type to reveal the solution/truth of the mystery."
                    } else if questLower.contains("rescue") || questLower.contains("save") || questLower.contains("free") {
                        // Rescue quest - free the captive (may involve combat with captor)
                        encounterPrompt += " This is the FINAL encounter - use 'combat' type with 'hard' difficulty if rescuing from captor, or 'final' type if freeing from trap/prison."
                    } else if questLower.contains("negotiate") || questLower.contains("persuade") || questLower.contains("convince") || questLower.contains("diplomacy") {
                        // Diplomatic quest - final negotiation
                        encounterPrompt += " This is the FINAL encounter - use 'social' type for the critical negotiation/persuasion."
                    } else {
                        encounterPrompt += " This is the FINAL encounter - use 'final' type to resolve the quest goal."
                    }
                }
            }
            encounterPrompt += " Determine encounter type and difficulty. For trap encounters, scale danger with player level."
            logger.debug("[Encounter LLM] Prompt length: \(encounterPrompt.count) chars")
            let encounterResponse = try await encounterSession.respond(to: encounterPrompt, generating: EncounterDetails.self)
            encounter = encounterResponse.content
            
            enforceEncounterVariety(on: &encounter)
            
            logger.debug("[Encounter LLM] Success")

            if encounter.encounterType == "combat" {
                activeNPC = nil
                activeNPCTurns = 0
                monster = try await generateMonster(for: encounter, characterLevel: charLevel, location: location)
            } else if encounter.encounterType == "final" {
                // Final encounter for non-combat quest completion (finding artifact, solving mystery, etc.)
                // No monster generation - the Adventure LLM will present the quest objective
                activeNPC = nil
                activeNPCTurns = 0
            } else if encounter.encounterType == "social" {
                npc = try await generateOrRetrieveNPC(for: location, encounter: encounter)
                activeNPC = npc
                activeNPCTurns = 1
            } else {
                activeNPC = nil
                activeNPCTurns = 0
            }
        }

        let encounterHistory = buildEncounterHistory()
        let historySection = encounterHistory.isEmpty ? "" : "\n\(encounterHistory)"

        let adventureHistory = buildAdventureHistory()
        let adventureHistorySection = adventureHistory.isEmpty ? "" : "\nAdventure so far: \(adventureHistory)"

        var scenePrompt = String(format: L10n.scenePromptFormat, location, actionLine) + "\nEncounter: \(encounter.encounterType) (\(encounter.difficulty))\n" + contextSummary + buildEncounterContext(monster: monster, npc: npc) + adventureHistorySection + historySection

        // Add quest progression guidance based on encounter number
        if let adventure = adventureProgress {
            let nextEncounter = adventure.currentEncounter + 1
            let progressPercent = Double(nextEncounter) / Double(adventure.totalEncounters)

            if progressPercent <= 0.4 {
                // Early adventure (1-3 of 7): Setup
                scenePrompt += "\nQUEST STAGE - EARLY: Introduce clues, NPCs, or hints related to '\(adventure.questGoal)'. Establish what stands between the player and their goal."
            } else if progressPercent <= 0.85 {
                // Mid adventure (4-6 of 7): Active pursuit
                scenePrompt += "\nQUEST STAGE - MIDDLE: Directly advance toward '\(adventure.questGoal)'. If the quest is 'retrieve X', mention seeing/finding X or its location. If 'defeat Y', introduce Y or their lair. Make tangible progress."
            }

            if nextEncounter >= adventure.totalEncounters {
                let encountersOver = nextEncounter - adventure.totalEncounters
                let questLower = adventure.questGoal.lowercased()

                // Determine quest type and completion criteria
                var completionInstructions = ""
                if questLower.contains("find") || questLower.contains("retrieve") || questLower.contains("locate") || questLower.contains("discover") {
                    completionInstructions = "Present the artifact/item. Mark completed=true when player takes/claims it."
                } else if questLower.contains("defeat") || questLower.contains("kill") || questLower.contains("destroy") || questLower.contains("stop") {
                    completionInstructions = "Boss fight handled by combat system. Mark completed=true when combat is won."
                } else if questLower.contains("escort") || questLower.contains("protect") || questLower.contains("guide") {
                    completionInstructions = "Present the destination or final threat. Mark completed=true when destination reached or threat defeated."
                } else if questLower.contains("investigate") || questLower.contains("solve") || questLower.contains("uncover") {
                    completionInstructions = "Reveal the solution/truth. Mark completed=true when player acknowledges/understands the answer."
                } else if questLower.contains("rescue") || questLower.contains("save") || questLower.contains("free") {
                    completionInstructions = "Present captive/prisoner. Mark completed=true when freed (combat win or unlock action)."
                } else if questLower.contains("negotiate") || questLower.contains("persuade") || questLower.contains("convince") || questLower.contains("diplomacy") {
                    completionInstructions = "Present key NPC for negotiation. Mark completed=true when agreement reached."
                } else {
                    completionInstructions = "Present quest objective. Mark completed=true when player's action achieves the goal."
                }

                if encountersOver == 0 {
                    // This is the planned final encounter
                    scenePrompt += "\nCRITICAL - FINAL ENCOUNTER: This is encounter \(nextEncounter)/\(adventure.totalEncounters) - the planned final encounter. Quest: '\(adventure.questGoal)'. \(completionInstructions) DO NOT set completed=true unless the player's action actually completes the objective."
                } else if encountersOver < 3 {
                    // Grace period - 1-2 encounters past planned end
                    scenePrompt += "\nCRITICAL - EXTENDED FINALE: This is encounter \(nextEncounter)/\(adventure.totalEncounters) (extra turn \(encountersOver)/3). Quest: '\(adventure.questGoal)'. \(completionInstructions) After 3 extra encounters, the quest will fail."
                } else {
                    // Last chance - 3rd extra encounter
                    scenePrompt += "\nCRITICAL - FINAL CHANCE: This is encounter \(nextEncounter)/\(adventure.totalEncounters) (final extra turn 3/3). This is the LAST opportunity to complete '\(adventure.questGoal)'. \(completionInstructions) If not completed this turn, the quest fails."
                }
            }
        }

        scenePrompt += "\nCRITICAL: If the encounter is combat or final, DO NOT resolve any fighting in the narration. Only describe the monster appearing and the setup. Keep the narration to EXACTLY 2-4 sentences."

        // Smart truncation to preserve critical instructions
        let maxPromptLength = 1500
        if scenePrompt.count > maxPromptLength {
            logger.warning("[Adventure LLM] Prompt too long (\(scenePrompt.count) chars), applying smart truncation to \(maxPromptLength)")
            scenePrompt = smartTruncatePrompt(scenePrompt, maxLength: maxPromptLength)
        }

        logger.debug("[Adventure LLM] Prompt length: \(scenePrompt.count) chars")
        lastPrompt = scenePrompt
        let adventureResponse = try await adventureSession.respond(to: scenePrompt, generating: AdventureTurn.self)
        let turn = adventureResponse.content
        logger.debug("[Adventure LLM] Success")
        
        var sanitizedTurn = turn
        sanitizedTurn.narration = sanitizeNarration(turn.narration, for: encounter.encounterType)

        var progressionPrompt = "Encounter type: \(encounter.encounterType). Difficulty: \(encounter.difficulty). Character level: \(charLevel). Adventure encounter: \(adventureProgress?.progress ?? "0/10")."
        if let adventure = adventureProgress {
            progressionPrompt += " Quest: \(adventure.questGoal)."
        }
        if encounter.encounterType.lowercased() == "social" {
            progressionPrompt += " Social encounters may grant XP (2–5) for meaningful conversations but should not grant gold."
        }
        logger.debug("[Progression LLM] Prompt length: \(progressionPrompt.count) chars")
        let progressionResponse = try await progressionSession.respond(to: progressionPrompt, generating: ProgressionRewards.self)
        let rewards = progressionResponse.content
        logger.debug("[Progression LLM] Success")

        var items: [ItemDefinition] = []
        if rewards.shouldDropLoot && rewards.itemDropCount > 0 {
            items = try await generateLoot(count: rewards.itemDropCount, difficulty: encounter.difficulty, characterLevel: charLevel, characterClass: character?.className ?? "Warrior")
        }

        // If the adventure is marked as completed, clear the pending monster before applying
        var finalMonster = monster
        if let progress = turn.adventureProgress, progress.completed {
            finalMonster = nil
        }

        await self.apply(turn: sanitizedTurn, encounter: encounter, rewards: rewards, loot: items, monster: finalMonster, npc: npc)
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

        // For other encounters, truncate narrative to max 100 chars
        let maxLength = 100
        let cleaned = narrative
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count <= maxLength {
            return cleaned
        }

        var summary = String(cleaned.prefix(maxLength))
        if let lastSpace = summary.lastIndex(of: " ") {
            summary = String(summary[..<lastSpace])
        }

        return summary
    }

    private func buildAdventureHistory() -> String {
        guard let progress = adventureProgress, !progress.encounterSummaries.isEmpty else {
            return ""
        }

        // Only include last 3 encounter summaries to prevent context overflow
        return progress.encounterSummaries.suffix(3).joined(separator: " → ")
    }

    private func buildContextSummary() -> String {
        guard let character = character else { return "" }

        var lines: [String] = []

        lines.append("Character: \(character.name) Lvl\(levelingService.level(forXP: character.xp)) \(character.className) HP:\(character.hp) Gold:\(character.gold)")

        if !currentEnvironment.isEmpty {
            lines.append("Current Location: \(currentEnvironment)")
        }

        if let adventure = adventureProgress {
            let questGoal = adventure.questGoal.count > 60 ? String(adventure.questGoal.prefix(60)) + "..." : adventure.questGoal
            lines.append("Quest: \(questGoal)")
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
        encounterKeywords.append(keywordString)

        if encounterKeywords.count > maxKeywordHistory {
            encounterKeywords.removeFirst()
        }
    }

    private func buildEncounterHistory() -> String {
        guard !encounterKeywords.isEmpty else { return "" }

        let numbered = encounterKeywords.enumerated().map { index, keywords in
            "\(index + 1): \(keywords)"
        }

        return "Encounter History: " + numbered.joined(separator: " | ")
    }

    // MARK: - Location Management
    func promptForNextLocation() async {
        guard var world = worldState else { return }

        let uncompletedLocations = world.locations.filter { !$0.completed }

        // Generate new locations if needed
        if uncompletedLocations.count < 2 {
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

        // Prompt for next location
        let availableLocations = worldState?.locations.filter { !$0.completed } ?? []
        if !availableLocations.isEmpty {
            appendModel("\nWhere would you like to venture next?")
            suggestedActions = availableLocations.map { $0.name }
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

    private func generateAdventureSummary(progress: AdventureProgress) async {
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
        showingAdventureSummary = true
    }

    // MARK: - Logging helpers
    private func appendPlayer(_ text: String) {
        log.append(LogEntry(content: String(format: L10n.playerPrefixFormat, text), isFromModel: false))
    }

    func appendModel(_ text: String) {
        log.append(LogEntry(content: text, isFromModel: true))
    }

    private func appendCharacterSprite() {
        guard let character = character else { return }
        log.append(LogEntry(content: "📜 NEW CHARACTER CREATED 📜", isFromModel: true, showCharacterSprite: true, characterForSprite: character))
    }

    private func appendMonsterSprite(_ monster: MonsterDefinition) {
        log.append(LogEntry(content: "⚔️ Monster: \(monster.fullName)", isFromModel: true, showMonsterSprite: true, monsterForSprite: monster))
    }
}

