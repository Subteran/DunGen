import Testing
import Foundation
import FoundationModels
@testable import DunGen

@MainActor
@Suite(.serialized)
struct TranscriptIntegrationTests {

    // MARK: - Quest Context Persistence Tests

    @Test("Quest context maintained across multiple turns", .enabled(if: Self.isLLMAvailable()))
    func testQuestContextPersistence() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        await setupGameWithAdventure(engine, preferredType: .village)

        let questGoal = engine.adventureProgress?.questGoal ?? ""
        #expect(!questGoal.isEmpty, "Quest goal should be set")

        // Take 5 turns and verify quest appears in every prompt
        for i in 1...5 {
            await engine.submitPlayer(input: "explore the area")

            let transcript = engine.sessionManager.getTranscript(for: .adventure)
            let hasQuest = TranscriptTestHelpers.verifyPromptContains(
                transcript: transcript,
                keyword: questGoal
            )

            #expect(hasQuest, "Quest '\(questGoal)' missing from prompt in turn \(i)")
        }
    }

    @Test("Location context persists across turns", .enabled(if: Self.isLLMAvailable()))
    func testLocationContextPersistence() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        await setupGameWithAdventure(engine, preferredType: .dungeon)

        let location = engine.adventureProgress?.locationName ?? ""
        #expect(!location.isEmpty, "Location should be set")

        // Take 3 turns and verify location appears in every prompt
        for i in 1...3 {
            await engine.submitPlayer(input: "look around")

            let transcript = engine.sessionManager.getTranscript(for: .adventure)
            let hasLocation = TranscriptTestHelpers.verifyPromptContains(
                transcript: transcript,
                keyword: location
            )

            #expect(hasLocation, "Location '\(location)' missing from prompt in turn \(i)")
        }
    }

    // MARK: - Context Window Tests

    @Test("Prompt sizes stay within limits", .enabled(if: Self.isLLMAvailable()))
    func testPromptSizeLimits() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        await setupGameWithAdventure(engine, preferredType: .outdoor)

        // Take 10 turns to build up context
        for _ in 1...10 {
            await engine.submitPlayer(input: "continue exploring")
        }

        let transcript = engine.getTranscript(for: .adventure)
        let analysis = TranscriptTestHelpers.analyzeContextUsage(from: transcript)

        // Verify no prompts exceed 600 char limit (our truncation threshold)
        #expect(analysis.over600Chars == 0, "Found \(analysis.over600Chars) prompts exceeding 600 chars")

        // Log metrics
        print("Context Analysis:")
        print("  Total Prompts: \(analysis.totalPrompts)")
        print("  Average Size: \(analysis.averageSize) chars")
        print("  Max Size: \(analysis.maxSize) chars")
        print("  Over 500 chars: \(analysis.over500Chars)")
    }

    @Test("Session reset clears transcript", .enabled(if: Self.isLLMAvailable()))
    func testSessionResetClearsTranscript() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        await setupGameWithAdventure(engine, preferredType: .village)

        // Take 3 turns
        for _ in 1...3 {
            await engine.submitPlayer(input: "explore")
        }

        let transcript1 = engine.sessionManager.getTranscript(for: .adventure)
        let count1 = TranscriptTestHelpers.entryCount(from: transcript1)
        #expect(count1 > 0, "Transcript should have entries before reset")

        // Force session reset
        engine.sessionManager.resetAll()

        let transcript2 = engine.sessionManager.getTranscript(for: .adventure)
        let count2 = TranscriptTestHelpers.entryCount(from: transcript2)
        #expect(count2 == 0, "Transcript should be empty after reset")
    }

    // MARK: - Narrative Quality Tests

    @Test("No third-person pronouns in narrative", .enabled(if: Self.isLLMAvailable()))
    func testSecondPersonPOV() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        await setupGameWithAdventure(engine, preferredType: .village)

        // Take 5 turns and check each response
        for i in 1...5 {
            await engine.submitPlayer(input: "look around")

            let transcript = engine.sessionManager.getTranscript(for: .adventure)
            if let lastResponse = TranscriptTestHelpers.getLastResponse(from: transcript) {
                let lower = lastResponse.lowercased()

                // Check for third-person pronouns
                let hasThirdPerson = lower.contains(" he ") ||
                                    lower.contains(" she ") ||
                                    lower.contains("the hero") ||
                                    lower.contains("the warrior")

                #expect(!hasThirdPerson, "Turn \(i): Found third-person pronouns in response: \(lastResponse.prefix(100))")
            }
        }
    }

    @Test("Monster names consistent with context", .enabled(if: Self.isLLMAvailable()))
    func testMonsterNameConsistency() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        await setupGameWithAdventure(engine, preferredType: .dungeon)

        // Play until we encounter a combat
        var foundCombat = false
        for _ in 1...10 {
            await engine.submitPlayer(input: "explore deeper")

            if engine.combatManager.pendingMonster != nil {
                foundCombat = true
                break
            }
        }

        #expect(foundCombat, "Should encounter at least one monster in 10 turns")

        if let monster = engine.combatManager.pendingMonster {
            let transcript = engine.sessionManager.getTranscript(for: .adventure)
            if let lastPrompt = TranscriptTestHelpers.getLastPrompt(from: transcript) {
                // Prompt should contain monster's full name
                #expect(lastPrompt.contains(monster.fullName), "Prompt should contain monster name '\(monster.fullName)'")
            }

            if let lastResponse = TranscriptTestHelpers.getLastResponse(from: transcript) {
                // Extract monster name components
                let nameWords = monster.fullName.lowercased().split(separator: " ").map(String.init)

                // Response should mention at least one component of the monster name
                let responseContainsMonster = nameWords.contains { word in
                    lastResponse.lowercased().contains(word)
                }

                #expect(responseContainsMonster, "Response should reference monster '\(monster.fullName)'")
            }
        }
    }

    // MARK: - Context Label Tests

    @Test("Natural language context labels appear in prompts", .enabled(if: Self.isLLMAvailable()))
    func testNaturalLanguageLabels() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        await setupGameWithAdventure(engine, preferredType: .village)

        await engine.submitPlayer(input: "explore")

        let transcript = engine.getTranscript(for: .adventure)
        if let lastPrompt = TranscriptTestHelpers.getLastPrompt(from: transcript) {
            // Verify natural language labels are used
            let hasNaturalLabels = lastPrompt.contains("Character:") ||
                                    lastPrompt.contains("Location:") ||
                                    lastPrompt.contains("Encounter Type:")

            #expect(hasNaturalLabels, "Prompt should use natural language labels (Character:, Location:, Encounter Type:)")
        }
    }

    // MARK: - Encounter Variety Tests

    @Test("Multiple encounter types generated", .enabled(if: Self.isLLMAvailable()))
    func testEncounterVariety() async throws {
        try? await Task.sleep(for: .milliseconds(500))
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        await setupGameWithAdventure(engine, preferredType: .outdoor)

        var encounterTypes = Set<String>()

        // Take 15 turns to see variety
        for _ in 1...15 {
            await engine.submitPlayer(input: "continue")

            if let encounterType = engine.lastEncounter {
                encounterTypes.insert(encounterType)
            }
        }

        // Should see at least 3 different encounter types in 15 turns
        #expect(encounterTypes.count >= 3, "Only saw \(encounterTypes.count) encounter types: \(encounterTypes)")
    }

    // MARK: - Helper Functions

    private func setupGameWithAdventure(_ engine: LLMGameEngine, preferredType: AdventureType) async {
        engine.checkAvailabilityAndConfigure()

        await engine.startNewGame(preferredType: preferredType, usedNames: [])

        if engine.awaitingWorldContinue {
            await engine.continueNewGame(usedNames: [])
        }

        if engine.awaitingLocationSelection, let firstLocation = engine.worldState?.locations.first {
            await engine.submitPlayer(input: firstLocation.name)

            // Wait for scene generation to complete
            var attempts = 0
            while engine.isGenerating && attempts < 100 {
                try? await Task.sleep(for: .milliseconds(100))
                attempts += 1
            }
        }
    }

    nonisolated private static func isLLMAvailable() -> Bool {
        return SystemLanguageModel.default.availability == .available
    }
}
