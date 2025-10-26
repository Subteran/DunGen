# Play Data Generation Guide

This guide explains how to use DunGen's automated play testing system to generate gameplay data for analysis.

## Overview

The system consists of three main components:

1. **AdventurePlayTest** - Automated adventure runner with 4 play strategies
2. **GameplayLogger** - Captures gameplay sessions to JSON files
3. **Test Examples** - Ready-to-run tests in `DunGenTests/PlayDataGenerationExample.swift`

## Quick Start

### Option 1: Run from Xcode

1. Open `DunGen.xcodeproj`
2. Navigate to `DunGenTests/PlayDataGenerationExample.swift`
3. Click the diamond icon (▷) next to any test:
   - `testSingleAdventure` - Quick test (1 adventure)
   - `testGenerate10Adventures` - Data generation (10 adventures)
4. View output in console and logs in `~/Documents/GameplayLogs/`

### Option 2: Run from Command Line

```bash
# Run a single adventure (quick test)
xcodebuild test -scheme DunGen \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:DunGenTests/PlayDataGenerationExample/testSingleAdventure

# Generate 10 adventures for data analysis (5-10 minutes)
xcodebuild test -scheme DunGen \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:DunGenTests/PlayDataGenerationExample/testGenerate10Adventures
```

## Data Output

### Location

All gameplay sessions are saved to:
```
~/Documents/GameplayLogs/session_<UUID>.json
```

### Example Session Data

```json
{
  "sessionId": "ABC-123-DEF-456",
  "startTime": "2025-10-23T10:30:00Z",
  "endTime": "2025-10-23T10:45:00Z",

  "characterName": "Grimgar Ironforge",
  "characterClass": "Warrior",
  "characterRace": "Dwarf",
  "finalLevel": 3,
  "finalHP": 25,

  "questType": "Retrieval",
  "questGoal": "Retrieve the stolen artifact from the icy caverns",
  "questCompleted": true,
  "questDuration": 900,

  "totalEncounters": 8,
  "encounterBreakdown": {
    "combat": 3,
    "exploration": 4,
    "final": 1
  },

  "narrativeSamples": [
    {
      "encounterNumber": 1,
      "encounterType": "combat",
      "difficulty": "normal",
      "playerAction": "Attack the goblin",
      "llmPrompt": "Quest: Retrieve artifact...",
      "llmResponse": "The goblin snarls as you draw your weapon...",
      "responseLength": 234,
      "hadCombatVerbs": false,
      "questStage": "EARLY"
    }
  ],

  "totalXPGained": 156,
  "totalGoldEarned": 243,
  "monstersDefeated": 3,
  "itemsCollected": 5,

  "deathOccurred": false,
  "deathCause": null,
  "deathEncounter": null
}
```

## Play Strategies

The system supports 4 different AI play strategies:

### 1. Aggressive
```swift
await playTest.runPlayTest(
    characterClass: .warrior,
    race: "Half-Orc",
    questType: .combat,
    strategy: .aggressive,
    maxTurns: 50
)
```
- Prioritizes combat actions
- Selects "Attack", "Fight", "Engage" when available
- Good for testing combat mechanics

### 2. Cautious
```swift
await playTest.runPlayTest(
    characterClass: .rogue,
    race: "Halfling",
    questType: .investigation,
    strategy: .cautious,
    maxTurns: 50
)
```
- Avoids combat when possible
- Prefers safe actions
- Good for testing survival mechanics

### 3. Balanced (Default)
```swift
await playTest.runPlayTest(
    characterClass: .mage,
    race: "Elf",
    questType: .retrieval,
    strategy: .balanced,
    maxTurns: 50
)
```
- Random action selection
- Balanced approach to gameplay
- Good for general testing

### 4. Exploratory
```swift
await playTest.runPlayTest(
    characterClass: .ranger,
    race: "Human",
    questType: .escort,
    strategy: .exploratory,
    maxTurns: 50
)
```
- Prioritizes search and investigation
- Selects "Look around", "Search", "Examine"
- Good for testing exploration mechanics

## Batch Testing

Generate multiple adventures for statistical analysis:

```swift
let playTest = AdventurePlayTest()

// Generate 10 adventures with random configurations
let results = await playTest.runBatchPlayTests(count: 10, strategy: .balanced)

// Analyze results
let completionRate = results.filter { $0.questCompleted }.count
print("Completion rate: \(completionRate)/10")
```

## Quest Types

Test all 6 quest types:

```swift
for questType in QuestType.allCases {
    let result = await playTest.runPlayTest(
        characterClass: .warrior,
        race: "Human",
        questType: questType,  // .retrieval, .combat, .escort, etc.
        strategy: .balanced
    )
}
```

Quest types:
- **Retrieval** - Find and claim an artifact
- **Combat** - Defeat a boss enemy
- **Escort** - Protect and guide an NPC
- **Investigation** - Solve a mystery
- **Rescue** - Free a captive
- **Diplomatic** - Negotiate an agreement

## Analytics

View aggregate statistics across all sessions:

```swift
let logger = GameplayLogger()

// Get all recorded sessions
let sessions = logger.getAllSessions()

// Generate analytics report
let report = logger.generateAnalyticsReport()
print(report)
```

The report includes:
- Total sessions analyzed
- Quest completion rate
- Average narrative response length (should be 2-4 sentences)
- Combat verb violation rate (combat should only happen in CombatView)
- Encounter type distribution
- Quest stage progression (EARLY/MIDDLE/FINAL)

## Use Cases

### 1. Narrative Quality Analysis
Check if the LLM is following the 2-4 sentence guideline:

```swift
let sessions = logger.getAllSessions()
for session in sessions {
    for sample in session.narrativeSamples {
        if sample.responseLength > 400 {
            print("⚠️ Long response: \(sample.responseLength) chars")
        }
    }
}
```

### 2. Combat Verb Detection
Verify combat narration doesn't happen outside CombatView:

```swift
let sessions = logger.getAllSessions()
for session in sessions {
    let violations = session.narrativeSamples.filter { $0.hadCombatVerbs }
    if !violations.isEmpty {
        print("⚠️ Combat verb violations: \(violations.count)")
    }
}
```

### 3. Quest Completion Rate
Measure how often quests are completed successfully:

```swift
let results = await playTest.runBatchPlayTests(count: 20, strategy: .balanced)
let completionRate = Double(results.filter { $0.questCompleted }.count) / Double(results.count)
print("Quest completion rate: \(completionRate * 100)%")
```

### 4. Balance Testing
Analyze XP/gold/item distribution:

```swift
let sessions = logger.getAllSessions()
let avgXP = sessions.map { $0.totalXPGained }.reduce(0, +) / sessions.count
let avgGold = sessions.map { $0.totalGoldEarned }.reduce(0, +) / sessions.count
let avgItems = sessions.map { $0.itemsCollected }.reduce(0, +) / sessions.count

print("Average per adventure:")
print("  XP: \(avgXP)")
print("  Gold: \(avgGold)")
print("  Items: \(avgItems)")
```

### 5. Generate Training Data
Create datasets for future LLM fine-tuning:

```bash
# Run 100 adventures
# Wait for completion
# Copy all JSON files
cp ~/Documents/GameplayLogs/*.json ./training_data/

# Analyze with external tools
python analyze_narratives.py ./training_data/
```

## Tips

1. **Start Small** - Run `testSingleAdventure` first to verify setup
2. **Monitor Progress** - Watch console output during batch runs
3. **Clean Old Data** - Periodically clear `~/Documents/GameplayLogs/`
4. **Adjust maxTurns** - Increase for longer adventures, decrease for quick tests
5. **Use Strategies** - Match strategy to quest type for realistic data

## Troubleshooting

### No JSON files created
- Check that tests completed successfully
- Verify permissions for `~/Documents/` directory
- Look for errors in console output

### Tests timeout
- Reduce `maxTurns` parameter
- Reduce batch count
- Check LLM availability on device

### Inconsistent results
- Run multiple batches for statistical significance
- Try different play strategies
- Check for death events (quest cannot complete if character dies)

## Example: Full Data Generation Session

```swift
// 1. Create play test instance
let playTest = AdventurePlayTest()

// 2. Test each quest type with different strategies
for questType in QuestType.allCases {
    for strategy in [.aggressive, .cautious, .balanced, .exploratory] {
        print("Testing \(questType) with \(strategy) strategy")

        let result = await playTest.runPlayTest(
            characterClass: CharacterClass.allCases.randomElement()!,
            race: ["Human", "Elf", "Dwarf"].randomElement()!,
            questType: questType,
            strategy: strategy,
            maxTurns: 40
        )

        print("  Result: completed=\(result.questCompleted), survived=\(result.survivedToEnd)")
    }
}

// 3. Generate analytics report
let logger = GameplayLogger()
let report = logger.generateAnalyticsReport()
print("\n" + report)

// 4. Check output directory
// open ~/Documents/GameplayLogs/
```

This generates 24 adventures (6 quest types × 4 strategies) with full narrative data.

## See Also

- `DunGenTests/PlayDataGenerationExample.swift` - Ready-to-run test examples
- `DunGen/Testing/AdventurePlayTest.swift` - Core play test implementation
- `DunGen/Managers/GameplayLogger.swift` - Session logging and analytics
- `REFACTORING_COMPLETE.md` - Architecture documentation
