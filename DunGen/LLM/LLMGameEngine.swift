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
                // Add starting healing potion to detailed inventory
                let startingPotion = ItemDefinition(
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
                detailedInventory.append(startingPotion)
                char.inventory.append(startingPotion.fullName)
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
            adventureProgress = progress
            if progress.isFinalEncounter && progress.completed {
                appendModel("\n✅ Adventure Complete: \(progress.locationName)")
                adventuresCompleted += 1

                // Mark location as completed
                if var world = worldState {
                    if let index = world.locations.firstIndex(where: { $0.name == progress.locationName }) {
                        world.locations[index].completed = true
                        world.locations[index].visited = true
                    }
                    worldState = world
                }

                // Generate adventure summary
                await generateAdventureSummary(progress: progress)
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

        if shouldApplyRewards, let xpGain = rewards?.xpGain {
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
        if shouldApplyRewards, let hpDelta = rewards?.hpDelta {
            if var char = self.character {
                char.hp += hpDelta
                char.hp = min(char.hp, char.maxHP)
                self.character = char
            }
            if hpDelta < 0 {
                appendModel("💔 Took \(abs(hpDelta)) damage!")
                checkDeath()
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
        if shouldApplyRewards, let gold = rewards?.goldGain, gold > 0 {
            currentAdventureGold += gold
            self.character?.gold += gold
            appendModel("💰 Found \(gold) gold!")
        }

        if let items = turn.itemsAcquired, !items.isEmpty {
            for item in items {
                self.character?.inventory.append(item)
                appendModel("📦 Acquired: \(item)")
            }
        }

        if let goldSpent = turn.goldSpent, goldSpent > 0 {
            if var char = self.character {
                if char.gold >= goldSpent {
                    char.gold -= goldSpent
                    self.character = char
                    appendModel("💸 Paid \(goldSpent) gold")
                } else {
                    appendModel("⚠️ Not enough gold! Need \(goldSpent) but only have \(char.gold)")
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
        let wasInCombat = combatManager.inCombat
        combatManager.performCombatAction(action)

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

        // Remove from inventory
        char.inventory.removeAll { $0 == itemName }
        detailedInventory.removeAll { $0.fullName == itemName || $0.baseName == itemName }

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

        var encounter: EncounterDetails
        var monster: MonsterDefinition?
        var npc: NPCDefinition?

        // Check if continuing an active NPC conversation
        let playerActionLower = (playerAction ?? "").lowercased()

        // Check if player specifically references the NPC by name or with keywords
        let isReferencingNPC = activeNPC != nil && (
            playerActionLower.contains(activeNPC!.name.lowercased()) ||
            playerActionLower.contains("speak") ||
            playerActionLower.contains("talk") ||
            playerActionLower.contains("ask") ||
            playerActionLower.contains("tell")
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
                    encounterPrompt += " This is the FINAL encounter - use 'final' type to satisfy the quest goal."
                }
            }
            encounterPrompt += " Determine encounter type and difficulty. For trap encounters, scale danger with player level."
            logger.debug("[Encounter LLM] Prompt length: \(encounterPrompt.count) chars")
            let encounterResponse = try await encounterSession.respond(to: encounterPrompt, generating: EncounterDetails.self)
            encounter = encounterResponse.content
            logger.debug("[Encounter LLM] Success")

            if encounter.encounterType == "combat" || encounter.encounterType == "final" {
                activeNPC = nil
                activeNPCTurns = 0
                monster = try await generateMonster(for: encounter, characterLevel: charLevel, location: location)
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

        var scenePrompt = String(format: L10n.scenePromptFormat, location, actionLine) + "\nEncounter: \(encounter.encounterType) (\(encounter.difficulty))\n" + contextSummary + buildEncounterContext(monster: monster, npc: npc) + historySection

        let maxPromptLength = 1000
        if scenePrompt.count > maxPromptLength {
            logger.warning("[Adventure LLM] Prompt too long (\(scenePrompt.count) chars), truncating to \(maxPromptLength)")
            scenePrompt = String(scenePrompt.prefix(maxPromptLength)) + "..."
        }

        logger.debug("[Adventure LLM] Prompt length: \(scenePrompt.count) chars")
        let adventureResponse = try await adventureSession.respond(to: scenePrompt, generating: AdventureTurn.self)
        let turn = adventureResponse.content
        logger.debug("[Adventure LLM] Success")

        var progressionPrompt = "Encounter type: \(encounter.encounterType). Difficulty: \(encounter.difficulty). Character level: \(charLevel). Adventure encounter: \(adventureProgress?.progress ?? "0/10")."
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
