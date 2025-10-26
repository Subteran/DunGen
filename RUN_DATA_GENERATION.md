# Quick Start: Generate 10 Adventures

This guide shows you how to quickly generate 10 gameplay sessions for data analysis.

## Running the Test

### From Xcode (Easiest)

1. Open `DunGen.xcodeproj`
2. Open `DunGenTests/PlayDataGenerationExample.swift`
3. Find the test `testGenerate10Adventures`
4. Click the diamond icon (▷) to the left of the function
5. Wait 5-10 minutes for completion
6. Check output: `open ~/Documents/GameplayLogs/`

### From Command Line

```bash
cd /Users/giant/Projects/DunGen

xcodebuild test -scheme DunGen \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:DunGenTests/PlayDataGenerationExample/testGenerate10Adventures
```

## What Gets Generated

### 10 JSON Files

Each file contains one complete adventure playthrough:

```
~/Documents/GameplayLogs/
├── session_abc123.json
├── session_def456.json
├── session_ghi789.json
... (10 total)
```

### Data in Each File

- **Character Info**: Name, class, race, level, HP
- **Quest Details**: Type, goal, completion status
- **Narrative Samples**: Full LLM prompts and responses
- **Encounter Breakdown**: Combat, exploration, social, etc.
- **Stats**: XP gained, gold earned, monsters defeated, items collected
- **Quality Metrics**: Response lengths, combat verb violations

## What the Test Does

1. **Creates 10 random adventures** with:
   - Random character classes (Warrior, Mage, Rogue, etc.)
   - Random races (Human, Elf, Dwarf, etc.)
   - Random quest types (Retrieval, Combat, Escort, etc.)
   - Balanced AI strategy (random action selection)

2. **Runs each adventure** for up to 50 turns or until:
   - Quest is completed
   - Character dies
   - Turn limit reached

3. **Logs everything** to JSON:
   - Every LLM prompt and response
   - Every player action
   - All rewards and items
   - Quest stage progression (EARLY/MIDDLE/FINAL)

4. **Prints summary** when complete:
   ```
   📊 Data Generation Complete:
      Total Adventures: 10
      Quests Completed: 7
      Survived to End: 8
      Average Encounters: 12
      Average Final Level: 2
   ```

## Console Output Example

```
🎮 Starting data generation: 10 adventures
   This will take 5-10 minutes...

[PlayTest] Starting adventure: Warrior Human, quest: Retrieval
[PlayTest] Turn 1: Continue exploring
[PlayTest] Turn 2: Attack the goblin
...
[PlayTest] Completed: quest=true, survived=true, turns=8

[PlayTest] Starting adventure: Mage Elf, quest: Combat
...

📊 Data Generation Complete:
   Total Adventures: 10
   Quests Completed: 7
   Survived to End: 8
   Average Encounters: 12
   Average Final Level: 2

✅ All session data saved to ~/Documents/GameplayLogs/
   View with: open ~/Documents/GameplayLogs/
```

## Viewing the Data

### Open in Finder

```bash
open ~/Documents/GameplayLogs/
```

### View a Session File

```bash
cat ~/Documents/GameplayLogs/session_*.json | head -100
```

### Pretty Print JSON

```bash
cat ~/Documents/GameplayLogs/session_*.json | python3 -m json.tool | less
```

### Count Total Sessions

```bash
ls ~/Documents/GameplayLogs/ | wc -l
```

## What to Do With the Data

### 1. Analyze Narrative Quality

Check if LLM responses follow the 2-4 sentence guideline:

```bash
# Find long responses
grep -h "responseLength" ~/Documents/GameplayLogs/*.json | sort -n
```

### 2. Check Completion Rates

```bash
# Count completed quests
grep -c '"questCompleted": true' ~/Documents/GameplayLogs/*.json
```

### 3. Review Combat Verb Violations

LLM should not narrate combat resolution (only combat UI should):

```bash
# Find violations
grep -c '"hadCombatVerbs": true' ~/Documents/GameplayLogs/*.json
```

### 4. Export for Analysis

```bash
# Copy all to analysis directory
mkdir ~/Desktop/DunGen_Analysis
cp ~/Documents/GameplayLogs/*.json ~/Desktop/DunGen_Analysis/
```

## Customizing the Test

Want different configurations? Edit the test:

```swift
// In PlayDataGenerationExample.swift

// Change count (default: 10)
let results = await playTest.runBatchPlayTests(count: 20, strategy: .balanced)

// Change strategy
let results = await playTest.runBatchPlayTests(count: 10, strategy: .aggressive)

// Run specific configuration
let result = await playTest.runPlayTest(
    characterClass: .warrior,
    race: "Dwarf",
    questType: .combat,
    strategy: .aggressive,
    maxTurns: 30  // Change turn limit
)
```

## Troubleshooting

### Test Times Out

- Reduce `maxTurns` in the test (default: 50)
- Check device performance
- Ensure simulator is running

### No JSON Files Created

```bash
# Check directory exists
ls -la ~/Documents/GameplayLogs/

# Check permissions
ls -ld ~/Documents/

# Look for errors in test output
```

### Low Completion Rate

This is normal! The game is challenging:
- Characters can die
- Quests can fail after 3 extra turns
- Some quest types are harder than others

Expected completion rate: ~60-70%

## Next Steps

After generating data:

1. **Review PLAY_DATA_GENERATION.md** for detailed analysis techniques
2. **Check analytics** using GameplayLogger methods
3. **Generate more data** with different strategies
4. **Compare quest types** to balance difficulty

## See Also

- `PLAY_DATA_GENERATION.md` - Full documentation
- `PlayDataGenerationExample.swift` - All test examples
- `AdventurePlayTest.swift` - Core implementation
