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

        init(content: String, isFromModel: Bool) {
            self.id = UUID()
            self.content = content
            self.isFromModel = isFromModel
        }

        init(id: UUID, content: String, isFromModel: Bool) {
            self.id = id
            self.content = content
            self.isFromModel = isFromModel
        }
    }

    // Live log of the adventure
    var log: [LogEntry] = []

    // Generation state
    var isGenerating: Bool = false

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

    // Statistics tracking
    var gameStartTime: Date?
    var adventuresCompleted: Int = 0
    var itemsCollected: Int = 0

    // Death state
    var characterDied: Bool = false
    var deathReport: CharacterDeathReport?

    // Current action choices for the player
    var suggestedActions: [String] = []

    // Location selection state
    var awaitingLocationSelection: Bool = false

    // Character name input state
    var awaitingCustomCharacterName: Bool = false
    var partialCharacter: CharacterProfile?

    // Inventory management state
    var needsInventoryManagement: Bool = false
    var pendingLoot: [ItemDefinition] = []
    private let maxInventorySlots = 20

    // Model availability
    var availability: AvailabilityState = .unavailable("Checking model…")

    // MARK: - Private

    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "LLMGameEngine")
    private let levelingService: LevelingServiceProtocol

    // MARK: - Managers
    private let sessionManager = SpecialistSessionManager()
    let combatManager = CombatManager()
    let affixRegistry = AffixRegistry()
    let npcRegistry = NPCRegistry()

    var inCombat: Bool { combatManager.inCombat }
    var currentMonster: MonsterDefinition? { combatManager.currentMonster }
    var currentMonsterHP: Int { combatManager.currentMonsterHP }

    // MARK: - Setup
    nonisolated init(levelingService: LevelingServiceProtocol = DefaultLevelingService()) {
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
        currentEnvironment = ""
        suggestedActions.removeAll()
        awaitingLocationSelection = false
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
            guard let worldSession = getSession(for: .world),
                  let characterSession = getSession(for: .character) else { return }

            let worldPrompt = "Create a fantasy world with an engaging story and diverse starting locations."
            logger.debug("[World LLM - Initial] Prompt length: \(worldPrompt.count) chars")
            let worldResponse = try await worldSession.respond(to: worldPrompt, generating: WorldState.self)
            logger.debug("[World LLM - Initial] Generated \(worldResponse.content.locations.count) locations")

            // Ensure all new locations start as unvisited and uncompleted
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
                    appendModel("\u{2022} \(location.name) (\(location.locationType.rawValue)): \(location.description)")
                }
                appendModel("")
            }

            let characterPrompt = "Create a new character for a fantasy text adventure. Choose a random class from the available options to ensure variety."
            logger.debug("[Character LLM] Prompt length: \(characterPrompt.count) chars")

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
                character = generatedCharacter
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
            appendModel(String(format: L10n.gameIntroFormat, character!.name, character!.race, character!.className, character!.backstory))
            appendModel(String(format: L10n.startingAttributesFormat,
                               character!.attributes.strength,
                               character!.attributes.dexterity,
                               character!.attributes.constitution,
                               character!.attributes.intelligence,
                               character!.attributes.wisdom,
                               character!.attributes.charisma))

            // Prompt player to choose starting location
            if let world = worldState {
                appendModel("\nWhere would you like to begin your adventure?")
                suggestedActions = world.locations.map { $0.name }
                awaitingLocationSelection = true
            }

            saveState()
        } catch {
            logger.error("\(error.localizedDescription, privacy: .public)")
            appendModel(String(format: L10n.errorStartGameFormat, error.localizedDescription))
        }
        isGenerating = false
    }

    func submitPlayer(input: String) async {
        guard case .available = availability else { return }
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
            character = partial
            partialCharacter = nil
            awaitingCustomCharacterName = false

            appendModel(L10n.gameWelcome)
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

        guard let character else { return }

        // Check if player is initiating combat with a pending monster
        if let pendingMonster = combatManager.pendingMonster,
           !combatManager.inCombat,
           (truncatedInput.lowercased().contains("attack") || truncatedInput.lowercased().contains("fight") || truncatedInput.lowercased().contains("engage")) {
            combatManager.enterCombat(with: pendingMonster)
            saveState()
            isGenerating = false
            return
        }

        // Handle location selection
        if awaitingLocationSelection {
            if let world = worldState, let selectedLocation = world.locations.first(where: { $0.name.lowercased() == truncatedInput.lowercased() || truncatedInput.lowercased().contains($0.name.lowercased()) }) {
                currentLocation = selectedLocation.locationType
                awaitingLocationSelection = false

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

        if let progress = turn.adventureProgress {
            adventureProgress = progress
            if progress.isFinalEncounter && progress.completed {
                appendModel("\n✅ Adventure Complete: \(progress.locationName)")
                appendModel("\(progress.adventureStory)")
                adventuresCompleted += 1

                // Mark location as completed
                if var world = worldState {
                    if let index = world.locations.firstIndex(where: { $0.name == progress.locationName }) {
                        world.locations[index].completed = true
                        world.locations[index].visited = true
                    }
                    worldState = world
                }

                // Prompt for next location
                await promptForNextLocation()
            }
        }

        if let monster = monster {
            // Store monster as pending - don't enter combat automatically
            // Player must choose to attack via their action
            combatManager.pendingMonster = monster
            appendModel("\n⚔️ Monster: \(monster.fullName)")
            appendModel("HP: \(monster.hp) | Defense: \(monster.defense)")
            if !monster.abilities.isEmpty {
                appendModel("Abilities: \(monster.abilities.prefix(3).joined(separator: ", "))")
            }
        }

        if let npc = npc {
            appendModel("\n💬 NPC: \(npc.name) the \(npc.occupation)")
            if npc.interactionCount > 0 {
                appendModel("(You've met \(npc.interactionCount) time\(npc.interactionCount == 1 ? "" : "s") before)")
            }
        }

        if let xpGain = rewards?.xpGain {
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
        if let hpDelta = rewards?.hpDelta {
            self.character?.hp += hpDelta
            if hpDelta < 0 {
                appendModel("💔 Took \(abs(hpDelta)) damage!")
            } else if hpDelta > 0 {
                appendModel("❤️ Healed \(hpDelta) HP!")
            }
        }
        if let gold = rewards?.goldGain, gold > 0 {
            self.character?.gold += gold
            appendModel("💰 Found \(gold) gold!")
        }

        if !loot.isEmpty {
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

        if let nextType = turn.nextLocationType { self.currentLocation = nextType }

        if let environment = turn.currentEnvironment {
            self.currentEnvironment = environment
        }

        appendModel(turn.narration)
        if let prompt = turn.playerPrompt, !prompt.isEmpty {
            appendModel(prompt)
        }

        self.suggestedActions = turn.suggestedActions
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
                var prompt = "Generate a new \(rewardList) for a level \(level) \(className). Return only the new \(rewardList) name."

                // If we've had duplicates, explicitly mention them
                if attempts > 1 {
                    prompt += " IMPORTANT: Do NOT generate any of these already known abilities/spells: \(existingRewards.joined(separator: ", "))."
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
            if characterLevel <= 3 { return monster.baseHP <= 30 }
            else if characterLevel <= 7 { return monster.baseHP > 20 && monster.baseHP <= 80 }
            else if characterLevel <= 12 { return monster.baseHP > 60 && monster.baseHP <= 150 }
            else { return monster.baseHP > 100 }
        }

        let randomBase = baseMonsters.randomElement() ?? MonsterDatabase.allMonsters[0]
        let knownAffixList = ""

        let prompt = "Base monster: \(randomBase.name) (\(randomBase.description)). Character level: \(characterLevel). Difficulty: \(encounter.difficulty). Location: \(location). Known affixes: \(knownAffixList.isEmpty ? "none yet" : knownAffixList). Generate modified monster with appropriate scaling and optional affixes."
        logger.debug("[Monster LLM] Prompt length: \(prompt.count) chars")

        let response = try await monsterSession.respond(to: prompt, generating: MonsterDefinition.self)
        logger.debug("[Monster LLM] Generated: \(response.content.fullName)")
        let monster = response.content

        if let prefix = monster.prefix {
            affixRegistry.registerMonsterAffix(prefix)
        }
        if let suffix = monster.suffix {
            affixRegistry.registerMonsterAffix(suffix)
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

    private func generateLoot(count: Int, difficulty: String, characterLevel: Int, characterClass: String) async throws -> [ItemDefinition] {
        guard let equipmentSession = getSession(for: .equipment) else { return [] }

        var items: [ItemDefinition] = []
        let knownAffixList = ""

        for i in 0..<count {
            let prompt = "Character level: \(characterLevel). Class: \(characterClass). Difficulty: \(difficulty). Known affixes: \(knownAffixList.isEmpty ? "none yet" : knownAffixList). Generate one magical item appropriate for this class and level."
            logger.debug("[Equipment LLM] Item \(i+1)/\(count) Prompt length: \(prompt.count) chars")

            let response = try await equipmentSession.respond(to: prompt, generating: ItemDefinition.self)
            logger.debug("[Equipment LLM] Item \(i+1)/\(count) Generated: \(response.content.fullName)")
            let item = response.content

            if let prefix = item.prefix {
                affixRegistry.registerItemAffix(prefix)
            }
            if let suffix = item.suffix {
                affixRegistry.registerItemAffix(suffix)
            }

            items.append(item)
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
        combatManager.performCombatAction(action)
    }

    func fleeCombat() -> Bool {
        return combatManager.fleeCombat()
    }

    func surrenderCombat() {
        combatManager.surrenderCombat()
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

    private func advanceScene(kind: AdventureType, playerAction: String?) async throws {
        guard let adventureSession = getSession(for: .adventure),
              let encounterSession = getSession(for: .encounter),
              let progressionSession = getSession(for: .progression) else { return }

        sessionManager.incrementTurnCount()
        sessionManager.resetIfNeeded()

        let actionLine = playerAction.map { "Player action: \($0)" } ?? "Begin scene"
        let location = kind.rawValue
        let contextSummary = buildContextSummary()
        let charLevel = levelingService.level(forXP: character?.xp ?? 0)

        var encounterPrompt = "Character level \(charLevel). Location: \(location). Recent encounters: \(recentEncounterTypes.joined(separator: ", ")). Adventure progress: \(adventureProgress?.progress ?? "1/10")."
        if let adventure = adventureProgress {
            encounterPrompt += " Quest: \(adventure.questGoal)."
        }
        encounterPrompt += " Determine encounter type and difficulty."
        logger.debug("[Encounter LLM] Prompt length: \(encounterPrompt.count) chars")
        let encounterResponse = try await encounterSession.respond(to: encounterPrompt, generating: EncounterDetails.self)
        let encounter = encounterResponse.content
        logger.debug("[Encounter LLM] Success")

        var monster: MonsterDefinition?
        var npc: NPCDefinition?

        if encounter.encounterType == "combat" {
            monster = try await generateMonster(for: encounter, characterLevel: charLevel, location: location)
        } else if encounter.encounterType == "social" {
            npc = try await generateOrRetrieveNPC(for: location, encounter: encounter)
        }

        let scenePrompt = String(format: L10n.scenePromptFormat, location, actionLine) + "\nEncounter: \(encounter.encounterType) (\(encounter.difficulty))\n" + contextSummary + buildEncounterContext(monster: monster, npc: npc)
        logger.debug("[Adventure LLM] Prompt length: \(scenePrompt.count) chars")
        let adventureResponse = try await adventureSession.respond(to: scenePrompt, generating: AdventureTurn.self)
        let turn = adventureResponse.content
        logger.debug("[Adventure LLM] Success")

        var progressionPrompt = "Encounter type: \(encounter.encounterType). Difficulty: \(encounter.difficulty). Character level: \(charLevel). Adventure encounter: \(adventureProgress?.progress ?? "1/10")."
        if let adventure = adventureProgress {
            progressionPrompt += " Quest: \(adventure.questGoal)."
        }
        progressionPrompt += " Calculate appropriate rewards."
        logger.debug("[Progression LLM] Prompt length: \(progressionPrompt.count) chars")
        let progressionResponse = try await progressionSession.respond(to: progressionPrompt, generating: ProgressionRewards.self)
        let rewards = progressionResponse.content
        logger.debug("[Progression LLM] Success")

        var items: [ItemDefinition] = []
        if rewards.shouldDropLoot && rewards.itemDropCount > 0 {
            items = try await generateLoot(count: rewards.itemDropCount, difficulty: encounter.difficulty, characterLevel: charLevel, characterClass: character?.className ?? "Warrior")
        }

        await self.apply(turn: turn, encounter: encounter, rewards: rewards, loot: items, monster: monster, npc: npc)
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
            lines.append("Adventure Story: \(adventure.adventureStory)")
            lines.append("Progress: Encounter \(adventure.currentEncounter) of \(adventure.totalEncounters)\(adventure.isFinalEncounter ? " [FINAL ENCOUNTER]" : "")")
        }

        if !detailedInventory.isEmpty {
            let itemNames = detailedInventory.prefix(5).map { $0.displayName }.joined(separator: ", ")
            lines.append("Key Items: \(itemNames)")
        } else if !character.inventory.isEmpty {
            let items = character.inventory.prefix(5).joined(separator: ", ")
            lines.append("Equipment: \(items)")
        }

        if !character.abilities.isEmpty {
            let abilities = character.abilities.prefix(3).joined(separator: ", ")
            lines.append("Abilities: \(abilities)")
        }

        if !character.spells.isEmpty {
            let spells = character.spells.prefix(3).joined(separator: ", ")
            lines.append("Spells/Prayers: \(spells)")
        }

        if !recentEncounterTypes.isEmpty {
            lines.append("Recent Encounters: \(recentEncounterTypes.joined(separator: ", "))")
        }

        let recentActions = log.suffix(6).filter { !$0.isFromModel }.map { entry in
            // Truncate long actions to prevent prompt bloat
            let content = entry.content
            return content.count > 200 ? String(content.prefix(200)) + "..." : content
        }
        if !recentActions.isEmpty {
            lines.append("Recent Actions: \(recentActions.joined(separator: " | "))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Location Management
    private func promptForNextLocation() async {
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

    // MARK: - Logging helpers
    private func appendPlayer(_ text: String) {
        log.append(LogEntry(content: String(format: L10n.playerPrefixFormat, text), isFromModel: false))
    }

    func appendModel(_ text: String) {
        log.append(LogEntry(content: text, isFromModel: true))
    }
}
