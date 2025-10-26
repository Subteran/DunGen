# Troubleshooting Play Test Issues

## Common Issues and Solutions

### Issue 1: "Failed to generate character"

**Symptoms:**
```
[PlayTest] Starting adventure: Warrior Dwarf, quest: Retrieval
[PlayTest] Failed to generate character
📊 Single Adventure Results:
   Quest Completed: false
   Survived: false
   Encounters: 0
```

**Possible Causes:**

#### 1. LLM Not Available on Device

The on-device LLM (FoundationModels) requires:
- iOS 26.0 or later
- A16 chip or newer (iPhone 14 Pro or later)
- Sufficient available RAM

**Check availability:**
```swift
let engine = LLMGameEngine()
engine.checkAvailabilityAndConfigure()
print("Availability: \(engine.availability)")
```

**Expected output:**
```
Availability: available
```

**If unavailable:**
```
Availability: unavailable("Model not available on this device")
```

**Solution:**
- Use a real device (iPhone 14 Pro or later with iOS 26+)
- If using simulator, ensure you're using iPhone 16 simulator with iOS 26+
- Check Console.app for FoundationModels errors

#### 2. Saved Game State Interfering

If there's a saved game with a dead character or corrupted state:

**Solution:**
```bash
# Delete saved game state
rm ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Documents/gameState.json

# Or run this in terminal
find ~/Library/Developer/CoreSimulator -name "gameState.json" -delete
```

#### 3. Character Generation Failed

The LLM might fail to generate a valid character.

**Solution:**
- Check logs for LLM errors
- Try running the app manually first to verify LLM works
- Check available memory on device/simulator

### Issue 2: "Failed to start adventure"

**Symptoms:**
```
[PlayTest] Failed to start adventure
```

**Cause:**
World/adventure generation failed after character creation.

**Solution:**
- Check LLM availability (same as Issue 1)
- Verify the character was created successfully
- Check logs for specific LLM errors

### Issue 3: Test Times Out

**Symptoms:**
- Test runs for 10+ minutes
- Eventually times out or hangs

**Causes:**
- LLM generation is very slow
- Infinite loop in game logic
- Device/simulator is overloaded

**Solution:**
```swift
// Reduce maxTurns for faster testing
await playTest.runPlayTest(
    characterClass: .warrior,
    race: "Human",
    questType: .retrieval,
    strategy: .balanced,
    maxTurns: 10  // Reduced from 50
)
```

### Issue 4: No JSON Files Created

**Symptoms:**
```
ls ~/Documents/GameplayLogs/
# Empty directory or directory doesn't exist
```

**Causes:**
- GameplayLogger not initialized
- Session never completed
- Permissions issue

**Solution:**
```bash
# Check if directory exists
ls -la ~/Documents/GameplayLogs/

# Create directory manually
mkdir -p ~/Documents/GameplayLogs/

# Check permissions
ls -ld ~/Documents/
```

### Issue 5: Very Low Completion Rate

**Symptoms:**
```
📊 Batch Results Summary:
   Total Adventures: 10
   Quests Completed: 1  # Very low
   Survived to End: 3
```

**This is actually NORMAL!** The game is challenging:
- Characters can die in combat
- Quests can fail after 3 extra turns beyond the planned encounters
- Some quest types are harder than others

**Expected completion rate:** 60-70%

If completion rate is below 30%, check:
- Character starting HP (should have healing items)
- Combat damage balance
- Quest completion detection (retrieval quests)

## Debugging Steps

### Step 1: Verify LLM Works in App

Before running tests, verify the LLM works:

1. Run the app normally (not tests)
2. Create a new character
3. Complete at least one encounter
4. If this works, tests should work too

### Step 2: Check Console Logs

```bash
# Open Console.app
open -a Console

# Filter for DunGen
# Look for errors from FoundationModels framework
```

### Step 3: Run Single Test First

Don't start with batch testing:

```bash
# Run single test first
xcodebuild test -scheme DunGen \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:DunGenTests/PlayDataGenerationExample/testSingleAdventure
```

### Step 4: Add Debug Logging

Modify `AdventurePlayTest.swift`:

```swift
func runPlayTest(...) async -> PlayTestResult {
    logger.info("[PlayTest] Starting adventure")

    let engine = LLMGameEngine()
    engine.checkAvailabilityAndConfigure()

    logger.info("[PlayTest] Availability: \(await engine.availability)")

    await engine.startNewGame(preferredType: .outdoor, usedNames: [])

    logger.info("[PlayTest] Character: \(String(describing: await engine.character))")
    logger.info("[PlayTest] Adventure: \(String(describing: await engine.adventureProgress))")

    // ... rest of test
}
```

### Step 5: Check Device Requirements

**Simulator:**
- Name: iPhone 16 (or iPhone 15 Pro)
- OS: iOS 26.0
- Check: Settings > General > About > Model

**Real Device:**
- iPhone 14 Pro or later
- iOS 26.0 or later
- Not in Low Power Mode

## Known Limitations

### 1. Simulator Performance

The LLM runs slower on simulator than on device:
- Device: ~1-2 seconds per turn
- Simulator: ~3-5 seconds per turn

**Expected time for 10 adventures:**
- Device: ~5 minutes
- Simulator: ~10-15 minutes

### 2. Memory Constraints

Running many tests in sequence can cause memory issues:

**Solution:**
```swift
// Add cleanup between tests
for i in 1...10 {
    let result = await playTest.runPlayTest(...)
    results.append(result)

    // Give system time to cleanup
    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
}
```

### 3. LLM Variability

The LLM is non-deterministic:
- Same input can produce different outputs
- Quest completion rates vary
- Some runs fail randomly

This is expected behavior for LLM-based gameplay.

## Getting Help

If none of these solutions work:

1. **Check error logs:**
   ```bash
   # View test output
   xcodebuild test ... 2>&1 | tee test_output.log
   ```

2. **Verify environment:**
   - Xcode version
   - iOS version
   - Device/simulator model
   - Available memory

3. **Minimal test case:**
   ```swift
   @Test("Verify LLM availability")
   func testLLMAvailability() async throws {
       let engine = LLMGameEngine()
       engine.checkAvailabilityAndConfigure()
       let availability = await engine.availability
       print("LLM Availability: \(availability)")
       // Should print: available
   }
   ```

4. **File an issue** with:
   - Error logs
   - Device/simulator details
   - Xcode version
   - Steps to reproduce
