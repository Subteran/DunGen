import Testing
import Foundation
@testable import DunGen

/// Example tests showing how to generate gameplay data for analysis.
/// These tests create JSON logs in ~/Documents/GameplayLogs/
///
/// To run:
/// - Single test: Run from Xcode or use xcodebuild test -only-testing:DunGenTests/PlayDataGenerationExample/testSingleAdventure
/// - Batch tests: Uncomment @Test and run testBatchAdventures
///
/// Output location: ~/Documents/GameplayLogs/session_<UUID>.json
@Suite("Play Data Generation Examples")
struct PlayDataGenerationExample {

    /// Example 1: Run a single adventure with specific character/quest configuration
    ///
    /// This generates one gameplay session with:
    /// - Character: Dwarf Warrior
    /// - Quest: Retrieval type
    /// - Strategy: Balanced (random action selection)
    ///
    /// Output: One JSON file with narrative samples, encounter breakdown, and completion stats
    @Test("Generate single adventure playthrough")
    @MainActor
    func testSingleAdventure() async throws {
        let playTest = AdventurePlayTest()

        let result = await playTest.runPlayTest(
            characterClass: .warrior,
            race: "Dwarf",
            questType: .retrieval,
            strategy: .balanced,
            maxTurns: 50
        )

        print("📊 Single Adventure Results:")
        print("   Quest Completed: \(result.questCompleted)")
        print("   Survived: \(result.survivedToEnd)")
        print("   Encounters: \(result.encountersCompleted)")
        print("   Final Level: \(result.finalLevel)")
        print("   Session ID: \(result.sessionId)")
        print("\n✅ Session data saved to ~/Documents/GameplayLogs/")
    }

    /// Example 2: Generate 10 adventures for data collection
    ///
    /// This generates 10 gameplay sessions with:
    /// - Random character classes and races
    /// - Random quest types
    /// - Balanced strategy
    ///
    /// Output: 10 JSON files with full narrative data
    ///
    /// Run time: ~5-10 minutes depending on device performance
    @Test("Generate 10 adventures for data analysis")
    @MainActor
    func testGenerate10Adventures() async throws {
        let playTest = AdventurePlayTest()

        print("🎮 Starting data generation: 10 adventures")
        print("   This will take 5-10 minutes...\n")

        let results = await playTest.runBatchPlayTests(count: 10, strategy: .balanced)

        print("\n📊 Data Generation Complete:")
        print("   Total Adventures: \(results.count)")
        print("   Quests Completed: \(results.filter { $0.questCompleted }.count)")
        print("   Survived to End: \(results.filter { $0.survivedToEnd }.count)")
        print("   Average Encounters: \(results.map { $0.encountersCompleted }.reduce(0, +) / results.count)")
        print("   Average Final Level: \(results.map { $0.finalLevel }.reduce(0, +) / results.count)")
        print("\n✅ All session data saved to ~/Documents/GameplayLogs/")
        print("   View with: open ~/Documents/GameplayLogs/")
    }

    /// Example 3: Run batch adventures with custom count
    ///
    /// This generates multiple gameplay sessions with:
    /// - Random character classes and races
    /// - Random quest types
    /// - Specified strategy (aggressive, cautious, balanced, or exploratory)
    ///
    /// Output: Multiple JSON files, one per adventure
    ///
    /// NOTE: This test is disabled by default (commented out @Test) because it takes time.
    /// Uncomment the @Test attribute and adjust the count as needed.
    // @Test("Generate batch adventure data")
    @MainActor
    func testBatchAdventures() async throws {
        let playTest = AdventurePlayTest()

        print("🎮 Starting batch playtest: 5 adventures with balanced strategy")
        print("   This will take a few minutes...\n")

        let results = await playTest.runBatchPlayTests(count: 5, strategy: .balanced)

        print("\n📊 Batch Results Summary:")
        print("   Total Adventures: \(results.count)")
        print("   Quests Completed: \(results.filter { $0.questCompleted }.count)")
        print("   Survived to End: \(results.filter { $0.survivedToEnd }.count)")
        print("   Average Encounters: \(results.map { $0.encountersCompleted }.reduce(0, +) / results.count)")
        print("   Average Final Level: \(results.map { $0.finalLevel }.reduce(0, +) / results.count)")
        print("\n✅ All session data saved to ~/Documents/GameplayLogs/")
    }

    /// Example 4: Test different play strategies
    ///
    /// Demonstrates the 4 available strategies:
    /// - Aggressive: Prefers combat actions
    /// - Cautious: Avoids combat when possible
    /// - Balanced: Random action selection
    /// - Exploratory: Prefers search/investigate actions
    // @Test("Compare play strategies")
    @MainActor
    func testCompareStrategies() async throws {
        let playTest = AdventurePlayTest()

        let strategies: [AdventurePlayTest.PlayStrategy] = [.aggressive, .cautious, .balanced, .exploratory]

        for strategy in strategies {
            print("\n🎯 Testing strategy: \(strategy)")

            let result = await playTest.runPlayTest(
                characterClass: .warrior,
                race: "Human",
                questType: .combat,
                strategy: strategy,
                maxTurns: 30
            )

            print("   Completed: \(result.questCompleted), Survived: \(result.survivedToEnd), Encounters: \(result.encountersCompleted)")
        }

        print("\n✅ All strategy tests saved to ~/Documents/GameplayLogs/")
    }

    /// Example 5: Test specific quest types
    ///
    /// Runs one adventure for each quest type:
    /// - Retrieval: Find and claim an artifact
    /// - Combat: Defeat a boss enemy
    /// - Escort: Protect and guide an NPC
    /// - Investigation: Solve a mystery
    /// - Rescue: Free a captive
    /// - Diplomatic: Negotiate an agreement
    // @Test("Generate data for all quest types")
    @MainActor
    func testAllQuestTypes() async throws {
        let playTest = AdventurePlayTest()

        for questType in QuestType.allCases {
            print("\n🎯 Testing quest type: \(questType.rawValue)")

            let result = await playTest.runPlayTest(
                characterClass: CharacterClass.allCases.randomElement()!,
                race: ["Human", "Elf", "Dwarf", "Halfling"].randomElement()!,
                questType: questType,
                strategy: .balanced,
                maxTurns: 50
            )

            print("   Completed: \(result.questCompleted), Encounters: \(result.encountersCompleted)")
        }

        print("\n✅ All quest type data saved to ~/Documents/GameplayLogs/")
    }
}

// MARK: - Usage Instructions

/*
 HOW TO USE THIS SYSTEM TO GENERATE PLAY DATA:

 1. RUN TESTS FROM XCODE:
    - Open DunGen.xcodeproj
    - Navigate to DunGenTests/PlayDataGenerationExample.swift
    - Click the diamond icon next to any @Test function
    - Or: Product menu → Test (⌘U)

 2. RUN TESTS FROM COMMAND LINE:
    # Run a specific test
    xcodebuild test -scheme DunGen \
      -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
      -only-testing:DunGenTests/PlayDataGenerationExample/testSingleAdventure

    # Run all play data generation tests
    xcodebuild test -scheme DunGen \
      -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
      -only-testing:DunGenTests/PlayDataGenerationExample

 3. VIEW THE GENERATED DATA:
    # Open the logs directory
    open ~/Documents/GameplayLogs/

    # Each session creates a JSON file: session_<UUID>.json
    # Example contents:
    {
      "sessionId": "ABC-123",
      "characterName": "Grimgar Ironforge",
      "characterClass": "Warrior",
      "questType": "Retrieval",
      "questGoal": "Retrieve the stolen artifact from the icy caverns",
      "questCompleted": true,
      "totalEncounters": 8,
      "encounterBreakdown": {"combat": 3, "exploration": 4, "final": 1},
      "narrativeSamples": [
        {
          "encounterNumber": 1,
          "encounterType": "combat",
          "playerAction": "Attack the goblin",
          "llmPrompt": "...",
          "llmResponse": "...",
          "responseLength": 234,
          "hadCombatVerbs": false,
          "questStage": "EARLY"
        },
        ...
      ],
      "totalXPGained": 156,
      "totalGoldEarned": 243,
      "monstersDefeated": 3,
      "itemsCollected": 5
    }

 4. ANALYZE THE DATA:
    The GameplayLogger also provides analytics. To use it:

    let logger = GameplayLogger()
    let sessions = logger.getAllSessions()
    let report = logger.generateAnalyticsReport()
    print(report)

    This gives you:
    - Total sessions analyzed
    - Quest completion rate
    - Average narrative response length
    - Combat verb violation rate
    - Encounter type distribution
    - Quest stage progression

 5. CUSTOMIZE FOR YOUR NEEDS:
    - Adjust maxTurns to control adventure length
    - Change PlayStrategy to test different playstyles
    - Modify character classes and races
    - Target specific quest types
    - Run batch tests for statistical analysis

 6. USE CASES:
    - Test narrative quality (2-4 sentence guideline)
    - Detect combat verb violations (combat should only happen in CombatView)
    - Measure quest completion rates
    - Analyze XP/gold balance
    - Validate encounter variety
    - Generate training data for future LLM fine-tuning
 */
