import Foundation
import OSLog

@MainActor
final class AdventurePlayTest {
    private let logger = Logger(subsystem: "com.logicchaos.DunGen", category: "AdventurePlayTest")
    private let gameplayLogger = GameplayLogger()

    enum PlayStrategy {
        case aggressive
        case cautious
        case balanced
        case exploratory
    }

    struct PlayTestResult {
        let sessionId: String
        let questCompleted: Bool
        let survivedToEnd: Bool
        let encountersCompleted: Int
        let finalLevel: Int
        let narrativeQualityScore: Double
        let averageResponseLength: Int
        let combatVerbViolations: Int
        let duration: TimeInterval
        let characterClass: String
        let race: String
        let questType: String
    }

    func runPlayTest(
        characterClass: CharacterClass,
        race: String,
        questType: QuestType,
        strategy: PlayStrategy = .balanced,
        maxTurns: Int = 50
    ) async -> PlayTestResult {
        let startTime = Date()
        logger.info("[PlayTest] Starting adventure: \(characterClass.rawValue) \(race), quest: \(questType.rawValue)")

        let engine = LLMGameEngine()
        engine.checkAvailabilityAndConfigure()

        // Check LLM availability
        let availability = engine.availability
        guard case .available = availability else {
            logger.error("[PlayTest] LLM not available: \(String(describing: availability))")
            return failedResult(characterClass: characterClass, race: race, questType: questType)
        }

        await engine.startNewGame(preferredType: .outdoor, usedNames: [])

        guard var character = engine.character else {
            logger.error("[PlayTest] Failed to generate character - startNewGame() did not create character")
            return failedResult(characterClass: characterClass, race: race, questType: questType)
        }

        // Customize character to match requested class/race
        character.className = characterClass.rawValue
        character.race = race
        engine.character = character

        // Continue to generate world
        await engine.continueNewGame(usedNames: [])

        guard let world = engine.worldState else {
            logger.error("[PlayTest] Failed to generate world")
            return failedResult(characterClass: characterClass, race: race, questType: questType)
        }

        // Select random location to start adventure
        guard let randomLocation = world.locations.randomElement() else {
            logger.error("[PlayTest] No locations available in world")
            return failedResult(characterClass: characterClass, race: race, questType: questType)
        }

        await engine.submitPlayer(input: randomLocation.name)

        guard let progress = engine.adventureProgress else {
            logger.error("[PlayTest] Failed to start adventure after selecting location")
            return failedResult(characterClass: characterClass, race: race, questType: questType)
        }

        gameplayLogger.startSession(
            character: character,
            questType: questType.rawValue,
            questGoal: progress.questGoal
        )

        var turnCount = 0
        var questCompleted = false
        var survivedToEnd = true

        while turnCount < maxTurns && !questCompleted && survivedToEnd {
            turnCount += 1

            let action = await selectAction(for: strategy, engine: engine, turn: turnCount)

            logger.info("[PlayTest] Turn \(turnCount): \(action)")

            await engine.submitPlayer(input: action)
            let promptAfter = engine.lastPrompt

            if let lastLog = engine.log.last {
                let currentProgress = engine.adventureProgress
                let questStage = currentProgress.map { progress in
                    let percent = Double(progress.currentEncounter) / Double(progress.totalEncounters)
                    if percent <= 0.4 { return "EARLY" }
                    else if percent <= 0.85 { return "MIDDLE" }
                    else { return "FINAL" }
                } ?? "UNKNOWN"

                gameplayLogger.logEncounter(
                    encounterNumber: currentProgress?.currentEncounter ?? 0,
                    encounterType: "unknown",
                    difficulty: "normal",
                    playerAction: action,
                    llmPrompt: promptAfter,
                    llmResponse: lastLog.content,
                    questStage: questStage
                )
            }

            questCompleted = engine.adventureProgress?.completed ?? false
            survivedToEnd = (engine.character?.hp ?? 0) > 0

            if let char = engine.character {
                gameplayLogger.updateStats(
                    level: engine.getCharacterLevel(),
                    hp: char.hp,
                    xpGained: engine.currentAdventureXP,
                    goldEarned: engine.currentAdventureGold,
                    monstersDefeated: engine.currentAdventureMonsters,
                    itemsCollected: engine.itemsCollected
                )
            }

            if !survivedToEnd {
                logger.warning("[PlayTest] Character died on turn \(turnCount)")
                break
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let deathReport = survivedToEnd ? nil : engine.deathReport
        gameplayLogger.endSession(questCompleted: questCompleted, deathReport: deathReport)

        let duration = Date().timeIntervalSince(startTime)
        logger.info("[PlayTest] Completed: quest=\(questCompleted), survived=\(survivedToEnd), turns=\(turnCount)")

        return PlayTestResult(
            sessionId: UUID().uuidString,
            questCompleted: questCompleted,
            survivedToEnd: survivedToEnd,
            encountersCompleted: turnCount,
            finalLevel: engine.getCharacterLevel(),
            narrativeQualityScore: 0.0,
            averageResponseLength: 0,
            combatVerbViolations: 0,
            duration: duration,
            characterClass: characterClass.rawValue,
            race: race,
            questType: questType.rawValue
        )
    }

    private func selectAction(for strategy: PlayStrategy, engine: LLMGameEngine, turn: Int) async -> String {
        let suggestedActions = engine.suggestedActions

        guard !suggestedActions.isEmpty else {
            return defaultAction(for: strategy, turn: turn)
        }

        switch strategy {
        case .aggressive:
            let combatActions = suggestedActions.filter {
                $0.lowercased().contains("attack") ||
                $0.lowercased().contains("fight") ||
                $0.lowercased().contains("engage")
            }
            return combatActions.first ?? suggestedActions.first ?? "continue"

        case .cautious:
            let safeActions = suggestedActions.filter {
                !$0.lowercased().contains("attack") &&
                !$0.lowercased().contains("fight")
            }
            return safeActions.first ?? suggestedActions.first ?? "look around"

        case .balanced:
            return suggestedActions.randomElement() ?? "continue"

        case .exploratory:
            let exploreActions = ["Look around", "Search the area", "Examine surroundings", "Investigate"]
            return exploreActions.randomElement() ?? suggestedActions.first ?? "continue"
        }
    }

    private func defaultAction(for strategy: PlayStrategy, turn: Int) -> String {
        switch strategy {
        case .aggressive:
            return ["Attack", "Engage the enemy", "Strike first", "Charge forward"].randomElement()!
        case .cautious:
            return ["Look around carefully", "Proceed cautiously", "Search for traps", "Listen for danger"].randomElement()!
        case .balanced:
            return ["Continue", "Proceed", "Move forward", "Keep going"].randomElement()!
        case .exploratory:
            return ["Examine the area", "Search thoroughly", "Investigate", "Look for clues"].randomElement()!
        }
    }

    private func failedResult(characterClass: CharacterClass = .warrior, race: String = "Human", questType: QuestType = .combat) -> PlayTestResult {
        PlayTestResult(
            sessionId: UUID().uuidString,
            questCompleted: false,
            survivedToEnd: false,
            encountersCompleted: 0,
            finalLevel: 1,
            narrativeQualityScore: 0.0,
            averageResponseLength: 0,
            combatVerbViolations: 0,
            duration: 0,
            characterClass: characterClass.rawValue,
            race: race,
            questType: questType.rawValue
        )
    }

    func runBatchPlayTests(count: Int, strategy: PlayStrategy = .balanced) async -> [PlayTestResult] {
        var results: [PlayTestResult] = []
        let batchStartTime = Date()

        print("\n========================================================")
        print("🎮 Starting Batch Test: \(count) Adventures")
        print("========================================================\n")

        for i in 1...count {
            logger.info("[PlayTest] Running batch test \(i)/\(count)")

            let randomClass = CharacterClass.allCases.randomElement()!
            let randomRace = ["Human", "Elf", "Dwarf", "Halfling", "Half-Elf", "Half-Orc", "Gnome", "Ursa"].randomElement()!
            let randomQuestType = QuestType.allCases.randomElement()!

            print("\n+-------------------------------------------------------+")
            print("| Adventure \(i)/\(count)")
            print("| Character: \(randomRace) \(randomClass.rawValue)")
            print("| Quest Type: \(randomQuestType.rawValue)")
            print("+-------------------------------------------------------+")

            let adventureStartTime = Date()
            let result = await runPlayTest(
                characterClass: randomClass,
                race: randomRace,
                questType: randomQuestType,
                strategy: strategy
            )
            let adventureDuration = Date().timeIntervalSince(adventureStartTime)
            results.append(result)

            // Show result
            let status = result.questCompleted ? "✅ COMPLETED" : (result.survivedToEnd ? "⚠️  INCOMPLETE" : "💀 DIED")
            print("\n   Result: \(status)")
            print("   Level: \(result.finalLevel) | Encounters: \(result.encountersCompleted) | Time: \(Int(adventureDuration))s")

            // Running stats
            let completed = results.filter { $0.questCompleted }.count
            let survived = results.filter { $0.survivedToEnd }.count
            let died = results.count - survived
            let avgEncounters = results.map { $0.encountersCompleted }.reduce(0, +) / results.count
            let avgLevel = results.map { $0.finalLevel }.reduce(0, +) / results.count

            print("\n   📊 Running Stats (\(results.count)/\(count)):")
            print("      Completed: \(completed) (\(Int(Double(completed) / Double(results.count) * 100))%)")
            print("      Survived: \(survived) | Died: \(died)")
            print("      Avg Encounters: \(avgEncounters) | Avg Level: \(avgLevel)")

            // Time estimate
            if i < count {
                let elapsed = Date().timeIntervalSince(batchStartTime)
                let avgTimePerAdventure = elapsed / Double(i)
                let remaining = avgTimePerAdventure * Double(count - i)
                let remainingMinutes = Int(remaining / 60)
                let remainingSeconds = Int(remaining) % 60
                print("\n   ⏱️  Estimated remaining: \(remainingMinutes)m \(remainingSeconds)s")
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        let totalDuration = Date().timeIntervalSince(batchStartTime)
        let totalMinutes = Int(totalDuration / 60)
        let totalSeconds = Int(totalDuration) % 60

        // Final summary
        let completed = results.filter { $0.questCompleted }.count
        let survived = results.filter { $0.survivedToEnd }.count
        let died = results.count - survived
        let avgEncounters = results.map { $0.encountersCompleted }.reduce(0, +) / results.count
        let avgLevel = results.map { $0.finalLevel }.reduce(0, +) / results.count

        print("\n\n========================================================")
        print("✅ Batch Test Complete")
        print("========================================================")
        print("")
        print("📊 Final Statistics:")
        print("   Total Adventures: \(count)")
        print("   Quests Completed: \(completed) (\(Int(Double(completed) / Double(count) * 100))%)")
        print("   Characters Survived: \(survived) (\(Int(Double(survived) / Double(count) * 100))%)")
        print("   Character Deaths: \(died)")
        print("   Average Encounters: \(avgEncounters)")
        print("   Average Final Level: \(avgLevel)")
        print("   Total Time: \(totalMinutes)m \(totalSeconds)s")
        print("")
        print("💾 Session data saved to:")
        print("   ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/")
        print("   Data/Application/*/Documents/GameplayLogs/")
        print("")
        print("💡 To find logs, run: ./FIND_LOGS.sh")
        print("========================================================\n")

        logger.info("[PlayTest] Batch complete: \(completed)/\(count) quests completed")

        return results
    }
}

enum QuestType: String, CaseIterable {
    case retrieval = "Retrieval"
    case combat = "Combat"
    case escort = "Escort"
    case investigation = "Investigation"
    case rescue = "Rescue"
    case diplomatic = "Diplomatic"
}
