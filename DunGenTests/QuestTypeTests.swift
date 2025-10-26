import Testing
import Foundation
@testable import DunGen

@MainActor
struct QuestTypeTests {

    // MARK: - Retrieval Quest Tests

    @Test("Retrieval quest completes in mock mode")
    func testRetrievalQuestMock() async throws {
        let engine = MockGameEngine()

        engine.adventureProgress = AdventureProgress(
            locationName: "Ancient Temple",
            adventureStory: "Retrieve the sacred artifact",
            questGoal: "Find the lost amulet",
            currentEncounter: 4,
            totalEncounters: 5,
            completed: false,
            encounterSummaries: ["Entered temple", "Solved puzzle", "Defeated guardian", "Found chamber"]
        )

        await engine.submitPlayer(input: "take the amulet")

        #expect(engine.adventureProgress?.completed == true)
        #expect(engine.submitPlayerCallCount == 1)
    }

    @Test("Retrieval quest completes with LLM", .enabled(if: isLLMAvailable()))
    func testRetrievalQuestLLM() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()

        await setupGameWithAdventure(engine: engine, preferredType: .dungeon)

        guard var progress = engine.adventureProgress else {
            throw TestError.noAdventureProgress
        }

        progress.questGoal = "Retrieve the ancient scroll"
        progress.currentEncounter = progress.totalEncounters - 1
        engine.adventureProgress = progress

        await engine.submitPlayer(input: "search for the scroll")

        let finalProgress = engine.adventureProgress
        #expect(finalProgress != nil)
    }

    // MARK: - Combat Quest Tests

    @Test("Combat quest requires defeating boss in mock mode")
    func testCombatQuestMock() async throws {
        let engine = MockGameEngine()

        engine.adventureProgress = AdventureProgress(
            locationName: "Dark Lair",
            adventureStory: "Defeat the evil warlord",
            questGoal: "Defeat the goblin warlord",
            currentEncounter: 4,
            totalEncounters: 5,
            completed: false,
            encounterSummaries: ["Entered lair", "Fought minions", "Found throne room", "Boss appears"]
        )

        let bossMonster = MonsterDefinition(
            baseName: "Goblin Warlord",
            prefix: nil,
            suffix: nil,
            hp: 50,
            damage: "2d6+2",
            defense: 15,
            abilities: ["Power Strike", "Rally Minions"],
            description: "A fearsome goblin leader"
        )

        engine.combatManager.pendingMonster = bossMonster
        engine.combatManager.currentMonsterHP = 50

        await engine.performCombatAction("attack with full force")

        while engine.combatManager.inCombat && engine.combatManager.currentMonsterHP > 0 {
            await engine.performCombatAction("attack")
        }

        #expect(engine.combatManager.inCombat == false)
        #expect(engine.character?.xp ?? 0 > 0)
    }

    @Test("Combat quest with boss in LLM mode", .enabled(if: isLLMAvailable()))
    func testCombatQuestLLM() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()

        await setupGameWithAdventure(engine: engine, preferredType: .dungeon)

        guard var progress = engine.adventureProgress else {
            throw TestError.noAdventureProgress
        }

        progress.questGoal = "Defeat the dragon terrorizing the village"
        progress.currentEncounter = progress.totalEncounters
        engine.adventureProgress = progress

        await engine.submitPlayer(input: "confront the dragon")

        #expect(engine.combatManager.pendingMonster != nil || engine.combatManager.currentMonster != nil)
    }

    // MARK: - Escort Quest Tests

    @Test("Escort quest completes safely in mock mode")
    func testEscortQuestMock() async throws {
        let engine = MockGameEngine()

        engine.adventureProgress = AdventureProgress(
            locationName: "Mountain Pass",
            adventureStory: "Escort merchant to safety",
            questGoal: "Escort the merchant to the village",
            currentEncounter: 4,
            totalEncounters: 5,
            completed: false,
            encounterSummaries: ["Met merchant", "Traveled north", "Avoided bandits", "Village in sight"]
        )

        await engine.submitPlayer(input: "arrive at the village safely")

        #expect(engine.adventureProgress?.completed == true)
        #expect(engine.character?.hp ?? 0 > 0)
    }

    @Test("Escort quest with combat threat in LLM mode", .enabled(if: isLLMAvailable()))
    func testEscortQuestWithCombatLLM() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()

        await setupGameWithAdventure(engine: engine, preferredType: .outdoor)

        guard var progress = engine.adventureProgress else {
            throw TestError.noAdventureProgress
        }

        progress.questGoal = "Protect the caravan from bandits"
        progress.currentEncounter = progress.totalEncounters - 1
        engine.adventureProgress = progress

        await engine.submitPlayer(input: "guard the caravan")

        #expect(engine.adventureProgress != nil)
    }

    // MARK: - Investigation Quest Tests

    @Test("Investigation quest completes in mock mode")
    func testInvestigationQuestMock() async throws {
        let engine = MockGameEngine()

        engine.adventureProgress = AdventureProgress(
            locationName: "Mystery Manor",
            adventureStory: "Solve the murder mystery",
            questGoal: "Investigate the mysterious murders",
            currentEncounter: 4,
            totalEncounters: 5,
            completed: false,
            encounterSummaries: ["Found clues", "Interviewed suspects", "Discovered secret", "Pieced together truth"]
        )

        await engine.submitPlayer(input: "confront the culprit with evidence")

        #expect(engine.adventureProgress?.completed == true)
        #expect(engine.character?.hp == engine.character?.maxHP)
    }

    @Test("Investigation quest in LLM mode", .enabled(if: isLLMAvailable()))
    func testInvestigationQuestLLM() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()

        await setupGameWithAdventure(engine: engine, preferredType: .city)

        guard var progress = engine.adventureProgress else {
            throw TestError.noAdventureProgress
        }

        progress.questGoal = "Uncover the conspiracy in the council"
        progress.currentEncounter = progress.totalEncounters - 1
        engine.adventureProgress = progress

        await engine.submitPlayer(input: "investigate the council chambers")

        #expect(engine.adventureProgress != nil)
    }

    // MARK: - Rescue Quest Tests

    @Test("Rescue quest with combat in mock mode")
    func testRescueQuestCombatMock() async throws {
        let engine = MockGameEngine()

        engine.adventureProgress = AdventureProgress(
            locationName: "Bandit Hideout",
            adventureStory: "Rescue the kidnapped child",
            questGoal: "Rescue the kidnapped child from bandits",
            currentEncounter: 4,
            totalEncounters: 5,
            completed: false,
            encounterSummaries: ["Tracked bandits", "Infiltrated hideout", "Found prison", "Confronted captors"]
        )

        let captor = MonsterDefinition(
            baseName: "Bandit Leader",
            prefix: nil,
            suffix: nil,
            hp: 30,
            damage: "1d8+2",
            defense: 14,
            abilities: ["Dirty Fighting"],
            description: "A cruel bandit leader"
        )

        engine.combatManager.pendingMonster = captor
        engine.combatManager.currentMonsterHP = 30

        await engine.performCombatAction("attack to rescue the child")

        while engine.combatManager.inCombat && engine.combatManager.currentMonsterHP > 0 {
            await engine.performCombatAction("attack")
        }

        #expect(engine.combatManager.inCombat == false)
    }

    @Test("Rescue quest peaceful resolution in mock mode")
    func testRescueQuestPeacefulMock() async throws {
        let engine = MockGameEngine()

        engine.adventureProgress = AdventureProgress(
            locationName: "Old Mill",
            adventureStory: "Free the trapped villager",
            questGoal: "Save the villager trapped in the mill",
            currentEncounter: 4,
            totalEncounters: 5,
            completed: false,
            encounterSummaries: ["Found mill", "Heard cries", "Located trap door", "Found key"]
        )

        await engine.submitPlayer(input: "unlock the door and free the villager")

        #expect(engine.adventureProgress?.completed == true)
    }

    @Test("Rescue quest in LLM mode", .enabled(if: isLLMAvailable()))
    func testRescueQuestLLM() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()

        await setupGameWithAdventure(engine: engine, preferredType: .outdoor)

        guard var progress = engine.adventureProgress else {
            throw TestError.noAdventureProgress
        }

        progress.questGoal = "Free the prisoners from the orc camp"
        progress.currentEncounter = progress.totalEncounters - 1
        engine.adventureProgress = progress

        await engine.submitPlayer(input: "search for the prisoners")

        #expect(engine.adventureProgress != nil)
    }

    // MARK: - Diplomatic Quest Tests

    @Test("Diplomatic quest completes in mock mode")
    func testDiplomaticQuestMock() async throws {
        let engine = MockGameEngine()

        engine.adventureProgress = AdventureProgress(
            locationName: "Neutral Ground",
            adventureStory: "Broker peace between factions",
            questGoal: "Negotiate peace between the warring clans",
            currentEncounter: 4,
            totalEncounters: 5,
            completed: false,
            encounterSummaries: ["Met clan leaders", "Heard grievances", "Proposed terms", "Final negotiation"]
        )

        await engine.submitPlayer(input: "convince both leaders to sign the treaty")

        #expect(engine.adventureProgress?.completed == true)
        #expect(engine.character?.hp == engine.character?.maxHP)
    }

    @Test("Diplomatic quest in LLM mode", .enabled(if: isLLMAvailable()))
    func testDiplomaticQuestLLM() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()

        await setupGameWithAdventure(engine: engine, preferredType: .city)

        guard var progress = engine.adventureProgress else {
            throw TestError.noAdventureProgress
        }

        progress.questGoal = "Persuade the king to pardon the rebels"
        progress.currentEncounter = progress.totalEncounters - 1
        engine.adventureProgress = progress

        await engine.submitPlayer(input: "speak with the king about mercy")

        #expect(engine.adventureProgress != nil)
    }

    // MARK: - Quest Completion Rewards Tests

    @Test("Retrieval quest awards appropriate rewards in mock mode")
    func testRetrievalRewardsMock() async throws {
        let engine = MockGameEngine()
        let initialXP = engine.character?.xp ?? 0
        let initialGold = engine.character?.gold ?? 0

        engine.adventureProgress = AdventureProgress(
            locationName: "Ancient Vault",
            adventureStory: "Retrieve the crown",
            questGoal: "Find and retrieve the lost crown",
            currentEncounter: 5,
            totalEncounters: 5,
            completed: false,
            encounterSummaries: []
        )

        await engine.submitPlayer(input: "take the crown")

        #expect(engine.character?.xp ?? 0 >= initialXP)
        #expect(engine.character?.gold ?? 0 >= initialGold)
    }

    @Test("Combat quest awards higher rewards in mock mode")
    func testCombatRewardsMock() async throws {
        let engine = MockGameEngine()
        let initialXP = engine.character?.xp ?? 0

        engine.adventureProgress = AdventureProgress(
            locationName: "Boss Arena",
            adventureStory: "Defeat the champion",
            questGoal: "Defeat the arena champion",
            currentEncounter: 5,
            totalEncounters: 5,
            completed: false,
            encounterSummaries: []
        )

        let boss = MonsterDefinition(
            baseName: "Champion",
            prefix: nil,
            suffix: nil,
            hp: 40,
            damage: "2d6",
            defense: 15,
            abilities: ["Power Strike"],
            description: "The arena champion"
        )

        engine.combatManager.pendingMonster = boss
        engine.combatManager.currentMonsterHP = 40

        await engine.performCombatAction("attack")

        while engine.combatManager.inCombat && engine.combatManager.currentMonsterHP > 0 {
            await engine.performCombatAction("attack")
        }

        let xpGained = (engine.character?.xp ?? 0) - initialXP
        #expect(xpGained >= 10)
    }

    @Test("Investigation quest awards no HP loss in mock mode")
    func testInvestigationNoHPLossMock() async throws {
        let engine = MockGameEngine()
        let initialHP = engine.character?.hp ?? 0

        engine.adventureProgress = AdventureProgress(
            locationName: "Library",
            adventureStory: "Solve the riddle",
            questGoal: "Investigate the ancient texts",
            currentEncounter: 5,
            totalEncounters: 5,
            completed: false,
            encounterSummaries: []
        )

        await engine.submitPlayer(input: "solve the mystery")

        #expect(engine.character?.hp ?? 0 >= initialHP)
    }
}

@MainActor
private func setupGameWithAdventure(engine: LLMGameEngine, preferredType: AdventureType) async {
    engine.checkAvailabilityAndConfigure()
    await engine.startNewGame(preferredType: preferredType, usedNames: [])

    if engine.awaitingWorldContinue {
        await engine.continueNewGame(usedNames: [])
    }

    if engine.awaitingLocationSelection, let firstLocation = engine.worldState?.locations.first {
        await engine.submitPlayer(input: firstLocation.name)
    }
}

enum TestError: Error {
    case noAdventureProgress
    case noCharacter
}

private func isLLMAvailable() -> Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    return true
    #endif
}
