import Foundation
import SwiftUI

struct PendingTransaction: Codable, Equatable {
    let items: [String]
    let cost: Int
    let npc: NPCDefinition?
}

struct GameLogEntry: Identifiable, Equatable, Codable {
    let id: UUID
    var content: String
    let isFromModel: Bool
    var isStreaming: Bool
    let showCharacterSprite: Bool
    let characterForSprite: CharacterProfile?
    let showMonsterSprite: Bool
    let monsterForSprite: MonsterDefinition?

    init(content: String, isFromModel: Bool, isStreaming: Bool = false, showCharacterSprite: Bool = false, characterForSprite: CharacterProfile? = nil, showMonsterSprite: Bool = false, monsterForSprite: MonsterDefinition? = nil) {
        self.id = UUID()
        self.content = content
        self.isFromModel = isFromModel
        self.isStreaming = isStreaming
        self.showCharacterSprite = showCharacterSprite
        self.characterForSprite = characterForSprite
        self.showMonsterSprite = showMonsterSprite
        self.monsterForSprite = monsterForSprite
    }

    init(id: UUID, content: String, isFromModel: Bool, isStreaming: Bool = false, showCharacterSprite: Bool = false, characterForSprite: CharacterProfile? = nil, showMonsterSprite: Bool = false, monsterForSprite: MonsterDefinition? = nil) {
        self.id = id
        self.content = content
        self.isFromModel = isFromModel
        self.isStreaming = isStreaming
        self.showCharacterSprite = showCharacterSprite
        self.characterForSprite = characterForSprite
        self.showMonsterSprite = showMonsterSprite
        self.monsterForSprite = monsterForSprite
    }
}

protocol GameEngine: AnyObject {
    var log: [GameLogEntry] { get }
    var character: CharacterProfile? { get set }
    var adventureProgress: AdventureProgress? { get set }
    var worldState: WorldState? { get set }
    var currentLocation: AdventureType { get set }
    var availability: LLMGameEngine.AvailabilityState { get }
    var detailedInventory: [ItemDefinition] { get set }

    var delegate: GameEngineDelegate? { get set }

    var awaitingLocationSelection: Bool { get set }
    var awaitingWorldContinue: Bool { get set }
    var characterDied: Bool { get set }
    var deathReport: CharacterDeathReport? { get set }
    var showingAdventureSummary: Bool { get set }
    var adventureSummary: AdventureSummary? { get set }
    var suggestedActions: [String] { get set }
    var isGenerating: Bool { get set }

    var inCombat: Bool { get }
    var currentMonster: MonsterDefinition? { get }
    var currentMonsterHP: Int { get }

    var needsInventoryManagement: Bool { get set }
    var pendingLoot: [ItemDefinition] { get set }
    var pendingTransaction: PendingTransaction? { get set }

    var combatManager: CombatManager { get }

    var adventuresCompleted: Int { get set }
    var itemsCollected: Int { get set }
    var totalMonstersDefeated: Int { get set }
    var totalXPEarned: Int { get set }
    var totalGoldEarned: Int { get set }
    var gameStartTime: Date? { get set }

    func startNewGame(preferredType: AdventureType?, usedNames: [String]) async
    func continueNewGame(usedNames: [String]) async
    func submitPlayer(input: String) async
    func promptForNextLocation() async
    func finalizeInventorySelection(_ selectedItems: [ItemDefinition])
    func fleeCombat() -> Bool
    func surrenderCombat()
    func useItem(itemName: String) -> Bool
    func performCombatAction(_ action: String) async

    func checkAvailabilityAndConfigure()
    func loadState()
    func saveState()
}

extension GameEngine {
    var inCombat: Bool { combatManager.inCombat }
    var currentMonster: MonsterDefinition? { combatManager.currentMonster }
}
