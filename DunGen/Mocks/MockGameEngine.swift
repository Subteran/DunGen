import Foundation
import SwiftUI

@MainActor
@Observable
final class MockGameEngine: GameEngine {
    weak var delegate: GameEngineDelegate?

    var log: [GameLogEntry] = []
    var character: CharacterProfile?
    var adventureProgress: AdventureProgress?
    var worldState: WorldState?
    var currentLocation: AdventureType = .outdoor
    var availability: LLMGameEngine.AvailabilityState = .available
    var detailedInventory: [ItemDefinition] = []

    var awaitingLocationSelection = false
    var awaitingWorldContinue = false
    var characterDied = false
    var deathReport: CharacterDeathReport?
    var showingAdventureSummary = false
    var adventureSummary: AdventureSummary?
    var suggestedActions: [String] = []
    var isGenerating = false

    var currentMonsterHP: Int { combatManager.currentMonsterHP }
    var needsInventoryManagement = false
    var pendingLoot: [ItemDefinition] = []
    var pendingTransaction: PendingTransaction?

    var combatManager = CombatManager()

    var adventuresCompleted: Int = 0
    var itemsCollected: Int = 0
    var totalMonstersDefeated: Int = 0
    var totalXPEarned: Int = 0
    var totalGoldEarned: Int = 0
    var gameStartTime: Date? = Date()

    private(set) var startNewGameCallCount = 0
    private(set) var submitPlayerCallCount = 0
    private(set) var lastSubmittedInput: String?

    init() {
        setupMockGame()
    }

    private func setupMockGame() {
        character = CharacterProfile(
            name: "Test Hero",
            race: "Human",
            className: "Warrior",
            backstory: "A test character for fast iteration",
            attributes: .init(strength: 16, dexterity: 14, constitution: 15, intelligence: 12, wisdom: 13, charisma: 14),
            hp: 20,
            maxHP: 20,
            xp: 0,
            gold: 50,
            inventory: [],
            abilities: ["Power Strike"],
            spells: []
        )

        worldState = WorldState(
            worldStory: "A test world for rapid development",
            locations: [
                WorldLocation(name: "Test Village", locationType: .village, description: "A peaceful test village"),
                WorldLocation(name: "Dark Forest", locationType: .outdoor, description: "A dangerous forest"),
                WorldLocation(name: "Ancient Ruins", locationType: .dungeon, description: "Mysterious ruins")
            ]
        )

        adventureProgress = AdventureProgress(
            locationName: "Test Village",
            adventureStory: "Testing the adventure system",
            questGoal: "Defeat the test monster",
            currentEncounter: 1,
            totalEncounters: 5,
            completed: false,
            encounterSummaries: []
        )

        log = [
            GameLogEntry(
                id: UUID(),
                content: "Welcome to the mock game engine! This is for fast iteration without LLM calls.",
                isFromModel: true,
                showCharacterSprite: false,
                characterForSprite: nil,
                showMonsterSprite: false,
                monsterForSprite: nil
            )
        ]

        suggestedActions = ["Attack", "Defend", "Explore", "Rest"]
    }

    func startNewGame(preferredType: AdventureType?, usedNames: [String]) async {
        startNewGameCallCount += 1
        setupMockGame()
        if let type = preferredType {
            currentLocation = type
        }
        appendLog("Starting new game in \(currentLocation.rawValue)...")
        try? await Task.sleep(for: .milliseconds(100))
        appendLog("Game started! You can now interact.")
    }

    func continueNewGame(usedNames: [String]) async {
        awaitingWorldContinue = false
        appendLog("Continuing adventure...")
    }

    func submitPlayer(input: String) async {
        submitPlayerCallCount += 1
        lastSubmittedInput = input

        appendLog("[PLAYER] \(input)", isFromModel: false)

        try? await Task.sleep(for: .milliseconds(50))

        if input.lowercased().contains("attack") {
            simulateCombat()
        } else if input.lowercased().contains("rest") {
            simulateRest()
        } else {
            appendLog("You \(input). The world reacts to your action.")
        }

        if let progress = adventureProgress {
            var updated = progress
            updated.currentEncounter += 1
            updated.encounterSummaries.append("Encounter \(updated.currentEncounter)")
            adventureProgress = updated

            if updated.currentEncounter >= updated.totalEncounters {
                appendLog("✅ Adventure Complete!")
                updated.completed = true
                adventureProgress = updated
                showingAdventureSummary = true
            }
        }
    }

    func promptForNextLocation() async {
        awaitingLocationSelection = true
        appendLog("Where would you like to venture next?")
        suggestedActions = worldState?.locations.map { $0.name } ?? []
    }

    func finalizeInventorySelection(_ selectedItems: [ItemDefinition]) {
        detailedInventory.append(contentsOf: selectedItems)
        pendingLoot = []
        needsInventoryManagement = false
    }

    func fleeCombat() -> Bool {
        combatManager.inCombat = false
        appendLog("You flee from combat!")
        return true
    }

    func surrenderCombat() {
        combatManager.surrenderCombat()
        appendLog("You surrender...")
    }

    func useItem(itemName: String) -> Bool {
        guard let itemIndex = detailedInventory.firstIndex(where: { $0.baseName == itemName || $0.fullName == itemName }) else {
            return false
        }

        let item = detailedInventory[itemIndex]
        if item.itemType.lowercased() == "consumable" {
            detailedInventory.remove(at: itemIndex)
            if let char = character {
                character?.hp = min(char.hp + 5, char.maxHP)
                appendLog("Used \(item.fullName). Restored 5 HP.")
            }
            return true
        }
        return false
    }

    func checkAvailabilityAndConfigure() {
        availability = .available
    }

    func loadState() {
        // Mock engine doesn't persist state
    }

    func saveState() {
        // Mock engine doesn't persist state
    }

    func performCombatAction(_ action: String) async {
        if !combatManager.inCombat, let pendingMonster = combatManager.pendingMonster {
            combatManager.inCombat = true
            combatManager.currentMonster = pendingMonster
            combatManager.currentMonsterHP = pendingMonster.hp
            combatManager.pendingMonster = nil
            appendLog("⚔️ Combat initiated with \(pendingMonster.fullName)!")
        }

        appendLog("[PLAYER] \(action)", isFromModel: false)
        try? await Task.sleep(for: .milliseconds(50))

        if action.lowercased().contains("attack") {
            if let monster = combatManager.currentMonster {
                let damage = Int.random(in: 3...8)
                combatManager.currentMonsterHP -= damage
                appendLog("You hit the \(monster.fullName) for \(damage) damage!")

                if combatManager.currentMonsterHP <= 0 {
                    appendLog("The \(monster.fullName) is defeated!")
                    combatManager.inCombat = false
                    character?.xp += 10
                    character?.gold += 5
                } else {
                    let monsterDamage = Int.random(in: 1...4)
                    character?.hp -= monsterDamage
                    appendLog("The \(monster.fullName) hits you for \(monsterDamage) damage!")
                }
            }
        }
    }

    private func simulateCombat() {
        let testMonster = MonsterDefinition(
            baseName: "Goblin",
            prefix: nil,
            suffix: nil,
            hp: 15,
            damage: "1d6",
            defense: 12,
            abilities: ["Club Attack"],
            description: "A small green creature"
        )

        combatManager.pendingMonster = testMonster
        combatManager.currentMonsterHP = testMonster.hp

        appendLog("A \(testMonster.fullName) appears! HP: \(testMonster.hp)")
    }

    private func simulateRest() {
        if let char = character {
            let healed = min(5, char.maxHP - char.hp)
            character?.hp += healed
            appendLog("You rest and recover \(healed) HP.")
        }
    }

    private func appendLog(_ content: String, isFromModel: Bool = true) {
        let entry = GameLogEntry(
            id: UUID(),
            content: content,
            isFromModel: isFromModel,
            showCharacterSprite: false,
            characterForSprite: nil,
            showMonsterSprite: false,
            monsterForSprite: nil
        )
        log.append(entry)
    }
}
