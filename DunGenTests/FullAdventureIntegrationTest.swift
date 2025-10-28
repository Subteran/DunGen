import Testing
import Foundation
@testable import DunGen

@MainActor
@Suite("Full Adventure Integration Tests")
struct FullAdventureIntegrationTest {

    @Test("Complete adventure sequence from character creation to quest completion",
          .timeLimit(.minutes(5)))
    func completeAdventureSequence() async throws {
        // GIVEN a new game engine
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())

        // Check LLM availability
        engine.checkAvailabilityAndConfigure()
        print("📱 LLM Availability: \(engine.availability)")

        guard case .available = engine.availability else {
            struct LLMUnavailableError: Error, CustomStringConvertible {
                var description: String { "LLM unavailable" }
            }
            throw LLMUnavailableError()
        }

        // WHEN starting a new game (will generate random character)
        print("🎲 Starting adventure in dungeon")

        await engine.startNewGame(
            preferredType: .dungeon,
            usedNames: []
        )

        // THEN character should be created
        let character = try #require(engine.character, "Character should be created")
        print("✅ Character created: \(character.name) - \(character.race) \(character.className)")
        print("   HP: \(character.hp)/\(character.maxHP), XP: \(character.xp), Gold: \(character.gold)")

        #expect(character.hp > 0)
        #expect(character.maxHP > 0)
        #expect(character.xp == 0)

        // Continue to generate world
        if engine.awaitingWorldContinue {
            print("🌍 Continuing to world generation...")
            await engine.continueNewGame(usedNames: [])
        }

        // THEN world locations should be generated
        #expect(engine.worldState != nil, "World should be generated")
        let locationCount = engine.worldState?.locations.count ?? 0
        print("🗺️  Generated \(locationCount) locations")
        #expect(locationCount >= 2)
        #expect(locationCount <= 5)

        // Select first location if awaiting selection
        if engine.awaitingLocationSelection, let firstLocation = engine.worldState?.locations.first {
            print("📍 Selecting location: \(firstLocation.name)")
            await engine.submitPlayer(input: firstLocation.name)
        }

        // THEN adventure should start
        #expect(engine.adventureProgress != nil)
        let progress = try #require(engine.adventureProgress, "Adventure should have started")
        print("🎯 Quest: \(progress.questGoal)")
        print("📊 Progress: \(progress.currentEncounter)/\(progress.totalEncounters)")

        var encounterCount = 0
        let maxEncounters = progress.totalEncounters + 3 // Allow extra encounters
        var questCompleted = false

        // Progress through encounters
        while encounterCount < maxEncounters && !engine.characterDied && !questCompleted {
            encounterCount += 1

            print("\n--- Encounter \(encounterCount) ---")

            // Determine action based on game state
            var action: String

            if engine.combatManager.inCombat {
                // Always attack in combat
                action = "Attack"
                print("⚔️  Combat: Attacking \(engine.combatManager.currentMonster?.fullName ?? "enemy")")
            } else if engine.combatManager.pendingMonster != nil {
                // Monster pending - attack to enter combat
                action = "Attack the \(engine.combatManager.pendingMonster?.fullName ?? "enemy")"
                print("⚔️  Engaging: \(engine.combatManager.pendingMonster?.fullName ?? "enemy")")
            } else if !engine.suggestedActions.isEmpty {
                // Choose random suggested action
                action = engine.suggestedActions.randomElement()!
                print("🎲 Action: \(action)")
            } else {
                // Fallback
                action = "continue"
                print("➡️  Continuing...")
            }

            // Submit action
            await engine.submitPlayer(input: action)

            // Log the LLM prompt and narrative
            if !engine.lastPrompt.isEmpty {
                print("🔤 LLM Prompt:\n\(engine.lastPrompt)\n")
            }

            // Find the actual narrative entry (from model, not combat/system messages)
            let narrativeEntries = engine.log.suffix(5).filter { $0.isFromModel && !$0.content.contains("⚔️") && !$0.content.contains("💔") && !$0.content.contains("✅") && !$0.content.contains("💰") }
            if let narrative = narrativeEntries.last {
                print("📖 Narrative: \(narrative.content)")
            } else if let lastLog = engine.log.last {
                print("📖 Last Log: \(lastLog.content)")
            }

            // Check progress
            if let currentProgress = engine.adventureProgress {
                print("📊 Progress: \(currentProgress.currentEncounter)/\(currentProgress.totalEncounters)")
                questCompleted = currentProgress.completed

                if questCompleted {
                    print("🎉 Quest completed!")
                }
            }

            if let char = engine.character {
                print("💚 HP: \(char.hp)/\(char.maxHP) | ⭐ XP: \(char.xp) | 💰 Gold: \(char.gold)")

                if char.hp <= 0 {
                    print("💀 Character died")
                    break
                }
            }

            // Safety check - stop if too many encounters
            if encounterCount >= maxEncounters {
                print("⚠️  Reached maximum encounter limit")
                break
            }
        }

        // THEN verify final state
        print("\n=== Final Results ===")
        if let finalChar = engine.character {
            print("Character: \(finalChar.name)")
            print("Status: \(finalChar.hp > 0 ? "Alive" : "Dead")")
            print("HP: \(finalChar.hp)/\(finalChar.maxHP)")
            print("XP: \(finalChar.xp)")
            print("Gold: \(finalChar.gold)")
            print("Inventory: \(finalChar.inventory.count + engine.detailedInventory.count) items")
        }

        if let finalProgress = engine.adventureProgress {
            print("Quest: \(finalProgress.completed ? "Completed" : "Failed/Incomplete")")
            print("Encounters: \(finalProgress.currentEncounter)/\(finalProgress.totalEncounters)")
        }

        print("Total combat victories: \(engine.combatManager.monstersDefeated)")

        // Print full narrative log
        print("\n=== FULL ADVENTURE LOG ===")
        print("Total entries: \(engine.log.count)\n")
        for (index, entry) in engine.log.enumerated() {
            let prefix = entry.isFromModel ? "🎭" : "👤"
            print("[\(index + 1)] \(prefix) \(entry.content)")
            if entry.showCharacterSprite, let char = entry.characterForSprite {
                print("    [Character Sprite: \(char.name) - \(char.race) \(char.className)]")
            }
            if entry.showMonsterSprite, let monster = entry.monsterForSprite {
                print("    [Monster Sprite: \(monster.fullName)]")
            }
        }
        print("=== END OF ADVENTURE LOG ===\n")

        // Verify test actually ran (lenient checks - character may die, quest may fail)
        #expect(encounterCount > 0, "Should have attempted at least one encounter")
        #expect(engine.log.count > 0, "Should have some narrative log entries")
    }

    @Test("Retrieval quest completes with final encounter presenting artifact",
          .timeLimit(.minutes(5)))
    func retrievalQuestCompletion() async throws {
        // Small delay to ensure clean start
        try? await Task.sleep(for: .milliseconds(500))

        // GIVEN a new game engine
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        // Check LLM availability
        engine.checkAvailabilityAndConfigure()
        guard case .available = engine.availability else {
            Issue.record("LLM not available - skipping integration test")
            return
        }

        // WHEN starting a new game
        print("🎲 Starting retrieval quest test")

        await engine.startNewGame(
            preferredType: .outdoor, // Outdoor tends to have retrieval quests
            usedNames: []
        )

        // THEN character should be created
        let character = try #require(engine.character, "Character should be created")
        print("✅ Character: \(character.name) - \(character.race) \(character.className)")

        // Continue to world generation
        if engine.awaitingWorldContinue {
            await engine.continueNewGame(usedNames: [])
        }

        // Select first location
        if engine.awaitingLocationSelection, let firstLocation = engine.worldState?.locations.first {
            print("📍 Location: \(firstLocation.name)")
            await engine.submitPlayer(input: firstLocation.name)
        }

        // Force-create a retrieval quest to ensure we test artifact mechanics
        var progress = try #require(engine.adventureProgress, "Adventure should have started")

        // Override quest goal to be a retrieval quest
        progress.questGoal = "Retrieve the ancient amulet"
        engine.adventureProgress = progress

        print("🎯 Quest (Force-Created): \(progress.questGoal)")
        print("📦 This is a RETRIEVAL quest - final encounter MUST present artifact")

        let isRetrievalQuest = true

        var turnCount = 0
        let maxTurns = (progress.totalEncounters * 3) + 5
        var questCompleted = false
        var hadFinalEncounter = false
        var finalEncounterHadMonster = false

        // Progress through encounters
        while turnCount < maxTurns && !engine.characterDied && !questCompleted {
            turnCount += 1
            let currentEncounterNum = engine.adventureProgress?.currentEncounter ?? 0
            print("\n--- Turn \(turnCount) (Encounter \(currentEncounterNum)/\(progress.totalEncounters)) ---")

            // Check if this is the final encounter
            let isFinalEncounter = engine.adventureProgress?.isFinalEncounter ?? false

            var action: String
            if engine.combatManager.inCombat {
                action = "Attack"
                print("⚔️  Combat: Attacking")
            } else if engine.combatManager.pendingMonster != nil {
                if isFinalEncounter && isRetrievalQuest {
                    finalEncounterHadMonster = true
                    print("❌ ERROR: Final encounter for retrieval quest has a monster!")
                }
                action = "Attack the \(engine.combatManager.pendingMonster?.fullName ?? "enemy")"
                print("⚔️  Engaging: \(engine.combatManager.pendingMonster?.fullName ?? "enemy")")
            } else {
                if isFinalEncounter {
                    hadFinalEncounter = true
                    print("🏁 Final encounter (non-combat) detected")
                    // For retrieval quests, try to take/claim the artifact
                    action = engine.suggestedActions.first ?? "Take the artifact"
                } else {
                    action = engine.suggestedActions.randomElement() ?? "continue"
                }
                print("🎲 Action: \(action)")
            }

            await engine.submitPlayer(input: action)

            if let currentProgress = engine.adventureProgress {
                questCompleted = currentProgress.completed
                print("📊 Progress: \(currentProgress.currentEncounter)/\(currentProgress.totalEncounters) - Completed: \(questCompleted)")
            }

            if let char = engine.character {
                print("💚 HP: \(char.hp)/\(char.maxHP) | XP: \(char.xp)")
            }

            if turnCount >= maxTurns {
                print("⚠️  Reached maximum turn limit")
                break
            }
        }

        // THEN verify retrieval quest results
        print("\n=== Retrieval Quest Test Results ===")
        print("Quest Type: \(isRetrievalQuest ? "Retrieval" : "Other")")
        print("Quest Completed: \(questCompleted)")
        print("Had Final Encounter: \(hadFinalEncounter)")
        print("Final Encounter Had Monster: \(finalEncounterHadMonster)")

        if isRetrievalQuest {
            // For retrieval quests, the final encounter should NOT have a monster
            if finalEncounterHadMonster {
                print("❌ TEST FAILURE: Retrieval quest final encounter generated a monster when it should be non-combat!")
            }
            #expect(!finalEncounterHadMonster, "Retrieval quest final encounter should not generate monster")
        }

        // Test passes if we successfully progressed through encounters
        #expect(turnCount > 0, "Should have progressed through at least one turn, got \(turnCount)")
    }

    @Test("Combat quest completes with final boss encounter",
          .timeLimit(.minutes(5)))
    func combatQuestCompletion() async throws {
        // Small delay to ensure previous test cleanup
        try? await Task.sleep(for: .milliseconds(500))

        // GIVEN a new game engine
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        // Check LLM availability
        engine.checkAvailabilityAndConfigure()
        guard case .available = engine.availability else {
            Issue.record("LLM not available - skipping integration test")
            return
        }

        // WHEN starting a new game
        print("🎲 Starting combat quest test")

        await engine.startNewGame(
            preferredType: .dungeon,
            usedNames: []
        )

        // THEN character should be created
        let character = try #require(engine.character, "Character should be created")
        print("✅ Character: \(character.name) - \(character.race) \(character.className)")

        // Continue to world generation
        if engine.awaitingWorldContinue {
            await engine.continueNewGame(usedNames: [])
        }

        // Select first location
        if engine.awaitingLocationSelection, let firstLocation = engine.worldState?.locations.first {
            print("📍 Location: \(firstLocation.name)")
            await engine.submitPlayer(input: firstLocation.name)
        }

        // Force-create a combat quest to ensure we test boss combat mechanics
        var progress = try #require(engine.adventureProgress, "Adventure should have started")

        // Override quest goal to be a combat quest
        progress.questGoal = "Eliminate the hobgoblin"
        engine.adventureProgress = progress

        print("🎯 Quest (Force-Created): \(progress.questGoal)")
        print("⚔️  This is a COMBAT quest - final encounter MUST have boss monster")

        let isCombatQuest = true

        var turnCount = 0
        let maxTurns = (progress.totalEncounters * 3) + 5
        var questCompleted = false
        var hadBossCombat = false
        var finalBossDefeated = false

        // Progress through encounters
        while turnCount < maxTurns && !engine.characterDied && !questCompleted {
            turnCount += 1
            let currentEncounterNum = engine.adventureProgress?.currentEncounter ?? 0
            print("\n--- Turn \(turnCount) (Encounter \(currentEncounterNum)/\(progress.totalEncounters)) ---")

            // Check if this is the final encounter with a boss
            let isFinalEncounter = engine.adventureProgress?.isFinalEncounter ?? false

            var action: String
            if engine.combatManager.inCombat {
                action = "Attack"
                print("⚔️  Combat: Attacking \(engine.combatManager.currentMonster?.fullName ?? "enemy")")

                if isFinalEncounter && isCombatQuest {
                    hadBossCombat = true
                    print("🔥 Final boss combat detected!")
                }
            } else if engine.combatManager.pendingMonster != nil {
                if isFinalEncounter && isCombatQuest {
                    hadBossCombat = true
                    print("🔥 Final boss appears: \(engine.combatManager.pendingMonster?.fullName ?? "enemy")")
                }
                action = "Attack the \(engine.combatManager.pendingMonster?.fullName ?? "enemy")"
                print("⚔️  Engaging: \(engine.combatManager.pendingMonster?.fullName ?? "enemy")")
            } else {
                action = engine.suggestedActions.randomElement() ?? "continue"
                print("🎲 Action: \(action)")
            }

            await engine.submitPlayer(input: action)

            // Check if we just defeated a boss in the final encounter
            if hadBossCombat && !engine.combatManager.inCombat && engine.combatManager.pendingMonster == nil {
                let defeatedCount = engine.combatManager.monstersDefeated
                if defeatedCount > 0 {
                    finalBossDefeated = true
                    print("✅ Boss defeated!")
                }
            }

            if let currentProgress = engine.adventureProgress {
                questCompleted = currentProgress.completed
                print("📊 Progress: \(currentProgress.currentEncounter)/\(currentProgress.totalEncounters) - Completed: \(questCompleted)")
            }

            if let char = engine.character {
                print("💚 HP: \(char.hp)/\(char.maxHP) | XP: \(char.xp)")
            }

            if turnCount >= maxTurns {
                print("⚠️  Reached maximum turn limit")
                break
            }
        }

        // THEN verify combat quest results
        print("\n=== Combat Quest Test Results ===")
        print("Quest Type: \(isCombatQuest ? "Combat" : "Other")")
        print("Quest Completed: \(questCompleted)")
        print("Had Boss Combat: \(hadBossCombat)")
        print("Boss Defeated: \(finalBossDefeated)")

        if isCombatQuest {
            // For combat quests, the final encounter SHOULD have a boss monster
            if !hadBossCombat {
                print("❌ TEST FAILURE: Combat quest did not have boss combat in final encounter!")
                print("   This could mean:")
                print("   1. Final encounter was never reached")
                print("   2. Final encounter didn't generate a monster")
                print("   3. Test timed out before final encounter")
            }
            #expect(hadBossCombat, "Combat quest should have boss combat in final encounter")
        }

        // Test passes if we successfully progressed through encounters
        #expect(turnCount > 0, "Should have progressed through at least one turn, got \(turnCount)")
    }

    @Test("Adventure handles character death correctly")
    func adventureHandlesDeath() async throws {
        // Small delay to ensure clean start
        try? await Task.sleep(for: .milliseconds(500))

        // GIVEN a character with 1 HP
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()
        engine.character = CharacterProfile(
            name: "Doomed Hero",
            race: "Human",
            className: "Warrior",
            backstory: "A brave but unlucky warrior.",
            attributes: .init(strength: 14, dexterity: 10, constitution: 12,
                            intelligence: 8, wisdom: 8, charisma: 10),
            hp: 1,
            maxHP: 15,
            xp: 50,
            gold: 20,
            inventory: [],
            abilities: [],
            spells: []
        )

        // WHEN character takes fatal damage
        engine.character?.hp = -5
        engine.checkDeath()

        // THEN death should be recorded
        #expect(engine.characterDied == true)
        #expect(engine.deathReport != nil)

        let report = try #require(engine.deathReport)
        #expect(report.character.name == "Doomed Hero")
        #expect(report.finalLevel > 0)

        // AND player input should be blocked
        await engine.submitPlayer(input: "continue")
        #expect(engine.log.last?.content != "continue")
    }
}
