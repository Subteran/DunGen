import Foundation
import OSLog

struct GameState: Codable, Equatable {
    var character: CharacterProfile?
    var currentLocation: AdventureType
    var currentEnvironment: String
    var log: [SavedLogEntry]
    var suggestedActions: [String]
    var adventureProgress: AdventureProgress?
    var detailedInventory: [ItemDefinition]
    var worldState: WorldState?
    var awaitingLocationSelection: Bool

    // Combat state
    var inCombat: Bool
    var currentMonster: MonsterDefinition?
    var currentMonsterHP: Int
    var pendingMonster: MonsterDefinition?

    // Pending trap state
    var pendingTrap: EncounterStateManager.PendingTrap?

    // Statistics tracking (lifetime stats across all adventures)
    var gameStartTime: Date?
    var adventuresCompleted: Int
    var itemsCollected: Int
    var totalMonstersDefeated: Int?
    var totalXPEarned: Int?
    var totalGoldEarned: Int?

    // Current adventure tracking
    var currentAdventureXP: Int
    var currentAdventureGold: Int
    var currentAdventureMonsters: Int

    // Adventure summary state
    var adventureSummary: AdventureSummary?
    var showingAdventureSummary: Bool

    // Inventory management state
    var needsInventoryManagement: Bool
    var pendingLoot: [ItemDefinition]

    // Trading state
    var pendingTransaction: PendingTransaction?

    // NPC conversation tracking
    var activeNPC: NPCDefinition?
    var activeNPCTurns: Int

    // Character creation flow
    var awaitingCustomCharacterName: Bool
    var partialCharacter: CharacterProfile?
    var awaitingWorldContinue: Bool

    // Encounter tracking for variety enforcement
    var encounterCounts: [String: Int]?
    var lastEncounter: String?
    var encountersSinceLastTrap: Int?

    struct SavedLogEntry: Codable, Equatable, Identifiable {
        let id: UUID
        let content: String
        let isFromModel: Bool
        let showCharacterSprite: Bool
        let characterForSprite: CharacterProfile?
        let showMonsterSprite: Bool
        let monsterForSprite: MonsterDefinition?
    }
}

protocol GameStatePersistenceProtocol {
    func save(_ state: GameState) throws
    func load() throws -> GameState?
    func delete() throws
}

final class GameStatePersistence: GameStatePersistenceProtocol {
    private let fileURL: URL

    init(fileName: String = "gameState.json") {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documentsDirectory.appendingPathComponent(fileName)
    }

    func save(_ state: GameState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }

    func load() throws -> GameState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(GameState.self, from: data)
    }

    func delete() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

extension LLMGameEngine {
    func saveState() {
        guard !disablePersistence else { return }
        let persistence = GameStatePersistence()
        let logEntries = log.map { entry in
            GameState.SavedLogEntry(
                id: entry.id,
                content: entry.content,
                isFromModel: entry.isFromModel,
                showCharacterSprite: entry.showCharacterSprite,
                characterForSprite: entry.characterForSprite,
                showMonsterSprite: entry.showMonsterSprite,
                monsterForSprite: entry.monsterForSprite
            )
        }

        let state = GameState(
            character: character,
            currentLocation: currentLocation,
            currentEnvironment: currentEnvironment,
            log: logEntries,
            suggestedActions: suggestedActions,
            adventureProgress: adventureProgress,
            detailedInventory: detailedInventory,
            worldState: worldState,
            awaitingLocationSelection: awaitingLocationSelection,
            inCombat: combatManager.inCombat,
            currentMonster: combatManager.currentMonster,
            currentMonsterHP: combatManager.currentMonsterHP,
            pendingMonster: combatManager.pendingMonster,
            pendingTrap: pendingTrap,
            gameStartTime: gameStartTime,
            adventuresCompleted: adventuresCompleted,
            itemsCollected: itemsCollected,
            totalMonstersDefeated: totalMonstersDefeated,
            totalXPEarned: totalXPEarned,
            totalGoldEarned: totalGoldEarned,
            currentAdventureXP: currentAdventureXP,
            currentAdventureGold: currentAdventureGold,
            currentAdventureMonsters: currentAdventureMonsters,
            adventureSummary: adventureSummary,
            showingAdventureSummary: showingAdventureSummary,
            needsInventoryManagement: needsInventoryManagement,
            pendingLoot: pendingLoot,
            pendingTransaction: pendingTransaction,
            activeNPC: activeNPC,
            activeNPCTurns: activeNPCTurns,
            awaitingCustomCharacterName: awaitingCustomCharacterName,
            partialCharacter: partialCharacter,
            awaitingWorldContinue: awaitingWorldContinue,
            encounterCounts: encounterCounts,
            lastEncounter: lastEncounter,
            encountersSinceLastTrap: encountersSinceLastTrap
        )

        do {
            try persistence.save(state)
        } catch {
            print("Failed to save game state: \(error)")
        }
    }

    func loadState() {
        guard !disablePersistence else {
            logger.info("Persistence disabled, skipping load")
            return
        }
        let persistence = GameStatePersistence()

        do {
            if let state = try persistence.load() {
                logger.info("Successfully loaded game state with character: \(state.character?.name ?? "none")")
                self.character = state.character
                self.currentLocation = state.currentLocation
                self.currentEnvironment = state.currentEnvironment
                self.log = state.log.map { savedEntry in
                    LLMGameEngine.LogEntry(
                        id: savedEntry.id,
                        content: savedEntry.content,
                        isFromModel: savedEntry.isFromModel,
                        showCharacterSprite: savedEntry.showCharacterSprite,
                        characterForSprite: savedEntry.characterForSprite,
                        showMonsterSprite: savedEntry.showMonsterSprite,
                        monsterForSprite: savedEntry.monsterForSprite
                    )
                }
                self.suggestedActions = state.suggestedActions
                self.adventureProgress = state.adventureProgress
                self.detailedInventory = state.detailedInventory
                self.worldState = state.worldState
                self.awaitingLocationSelection = state.awaitingLocationSelection

                // Restore combat state
                self.combatManager.inCombat = state.inCombat
                self.combatManager.currentMonster = state.currentMonster
                self.combatManager.currentMonsterHP = state.currentMonsterHP
                self.combatManager.pendingMonster = state.pendingMonster

                // Restore pending trap
                self.pendingTrap = state.pendingTrap

                // Restore statistics
                self.gameStartTime = state.gameStartTime
                self.adventuresCompleted = state.adventuresCompleted
                self.itemsCollected = state.itemsCollected
                self.totalMonstersDefeated = state.totalMonstersDefeated ?? 0
                self.totalXPEarned = state.totalXPEarned ?? 0
                self.totalGoldEarned = state.totalGoldEarned ?? 0

                // Restore current adventure tracking
                self.currentAdventureXP = state.currentAdventureXP
                self.currentAdventureGold = state.currentAdventureGold
                self.currentAdventureMonsters = state.currentAdventureMonsters

                // Restore adventure summary state
                self.adventureSummary = state.adventureSummary
                // Migration: Clear showingAdventureSummary if we have a summary (new behavior: manual trigger)
                self.showingAdventureSummary = false

                // Restore inventory management state
                self.needsInventoryManagement = state.needsInventoryManagement
                self.pendingLoot = state.pendingLoot

                // Restore trading state
                self.pendingTransaction = state.pendingTransaction

                // Restore NPC conversation tracking
                self.activeNPC = state.activeNPC
                self.activeNPCTurns = state.activeNPCTurns

                // Restore character creation flow
                self.awaitingCustomCharacterName = state.awaitingCustomCharacterName
                self.partialCharacter = state.partialCharacter
                self.awaitingWorldContinue = state.awaitingWorldContinue

                // Restore encounter tracking (with migration support)
                self.encounterCounts = state.encounterCounts ?? [:]
                self.lastEncounter = state.lastEncounter
                self.encountersSinceLastTrap = state.encountersSinceLastTrap ?? 0

                // Check if character died before save
                if let char = state.character, char.hp <= 0 {
                    checkDeath()
                }
            } else {
                logger.info("No saved game state found, starting fresh")
            }
        } catch {
            logger.error("Failed to load game state: \(error.localizedDescription)")
            print("Failed to load game state: \(error)")
        }
    }

    func deleteState() {
        let persistence = GameStatePersistence()

        do {
            try persistence.delete()
        } catch {
            print("Failed to delete game state: \(error)")
        }
    }
}
