import Foundation
import SwiftUI
import OSLog

@MainActor
@Observable
final class GameViewModel: GameEngineDelegate {
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "GameViewModel")
    private(set) var engine: LLMGameEngine

    var isGenerating: Bool = false
    var suggestedActions: [String] = []
    var showingLocationSelection: Bool = false
    var showingCustomCharacterName: Bool = false
    var showingInventoryManagement: Bool = false
    var showingWorldContinue: Bool = false
    var showingAdventureSummary: Bool = false

    var log: [GameLogEntry] { engine.log }
    var character: CharacterProfile? { engine.character }
    var adventureProgress: AdventureProgress? { engine.adventureProgress }
    var worldState: WorldState? { engine.worldState }
    var currentLocation: AdventureType { engine.currentLocation }
    var availability: LLMGameEngine.AvailabilityState { engine.availability }
    var detailedInventory: [ItemDefinition] { engine.detailedInventory }
    var characterDied: Bool { engine.characterDied }
    var deathReport: CharacterDeathReport? { engine.deathReport }
    var adventureSummary: AdventureSummary? { engine.adventureSummary }
    var inCombat: Bool { engine.inCombat }
    var currentMonster: MonsterDefinition? { engine.currentMonster }
    var currentMonsterHP: Int { engine.currentMonsterHP }
    var pendingLoot: [ItemDefinition] { engine.pendingLoot }
    var pendingTransaction: PendingTransaction? { engine.pendingTransaction }
    var awaitingWorldContinue: Bool { engine.awaitingWorldContinue }
    var needsInventoryManagement: Bool { engine.needsInventoryManagement }
    var combatManager: CombatManager { engine.combatManager }
    var awaitingLocationSelection: Bool { engine.awaitingLocationSelection }
    var adventuresCompleted: Int { engine.adventuresCompleted }
    var itemsCollected: Int { engine.itemsCollected }
    var totalMonstersDefeated: Int { engine.totalMonstersDefeated }
    var totalXPEarned: Int { engine.totalXPEarned }
    var totalGoldEarned: Int { engine.totalGoldEarned }
    var gameStartTime: Date? { engine.gameStartTime }

    init(engine: LLMGameEngine? = nil) {
        self.engine = engine ?? LLMGameEngine()
        self.engine.delegate = self
        self.engine.checkAvailabilityAndConfigure()
        self.engine.loadState()
    }

    func engineDidStartGenerating() {
        isGenerating = true
    }

    func engineDidFinishGenerating() {
        isGenerating = false
    }

    func engineNeedsLocationSelection(summary: AdventureSummary) {
        logger.info("[ViewModel] engineNeedsLocationSelection called with summary: \(summary.questGoal)")
        logger.info("[ViewModel] Current engine.adventureSummary is: \(self.engine.adventureSummary != nil ? "SET" : "NIL")")
        logger.info("[ViewModel] Current adventureSummary computed property is: \(self.adventureSummary != nil ? "SET" : "NIL")")
        logger.info("[ViewModel] Setting showingAdventureSummary to true")
        showingAdventureSummary = true
        logger.info("[ViewModel] showingAdventureSummary is now: \(self.showingAdventureSummary)")
    }

    func engineNeedsCustomCharacterName(partialCharacter: CharacterProfile) {
        showingCustomCharacterName = true
    }

    func engineNeedsInventoryManagement(pendingLoot: [ItemDefinition], currentInventory: [ItemDefinition]) {
        showingInventoryManagement = true
    }

    func engineNeedsWorldContinue() {
        showingWorldContinue = true
    }

    func engineDidUpdateSuggestedActions(_ actions: [String]) {
        suggestedActions = actions
    }

    func engineDidUpdateLog(_ log: [GameLogEntry]) {
    }

    func engineDidDetectDeath(report: CharacterDeathReport) {
        showingAdventureSummary = true
    }

    func startNewGame(preferredType: AdventureType?, usedNames: [String]) async {
        await engine.startNewGame(preferredType: preferredType, usedNames: usedNames)
    }

    func continueNewGame(usedNames: [String]) async {
        await engine.continueNewGame(usedNames: usedNames)
        showingWorldContinue = false
    }

    func submitPlayer(input: String) async {
        await engine.submitPlayer(input: input)
    }

    func promptForNextLocation() async {
        await engine.promptForNextLocation()
    }

    func finalizeInventorySelection(_ selectedItems: [ItemDefinition]) {
        engine.finalizeInventorySelection(selectedItems)
        showingInventoryManagement = false
    }

    func fleeCombat() -> Bool {
        engine.fleeCombat()
    }

    func surrenderCombat() {
        engine.surrenderCombat()
    }

    func useItem(itemName: String) -> Bool {
        engine.useItem(itemName: itemName)
    }

    func performCombatAction(_ action: String) async {
        await engine.performCombatAction(action)
    }

    func saveState() {
        engine.saveState()
    }
}
