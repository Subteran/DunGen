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
        guard case .available = engine.availability else {
            Issue.record("LLM not available - skipping integration test")
            return
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

    @Test("Adventure handles character death correctly")
    func adventureHandlesDeath() async throws {
        // GIVEN a character with 1 HP
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
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
