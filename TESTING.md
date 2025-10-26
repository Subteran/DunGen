# Testing Guide

## MockGameEngine Modes

The `MockGameEngine` supports two modes for flexible testing:

### Mock Mode (Default)
Fast, deterministic responses without requiring LLM availability. Perfect for:
- UI development and iteration
- Unit testing game logic
- CI/CD pipelines
- Offline development

```swift
let engine = MockGameEngine(mode: .mock)
// or
let engine = MockGameEngine() // defaults to .mock
```

### LLM Mode
Uses real LLM for testing actual game responses. Perfect for:
- Integration testing LLM output
- Validating prompt engineering
- Testing edge cases with real AI
- QA testing

```swift
let engine = MockGameEngine(mode: .llm)
```

## Usage Examples

### Unit Tests (Mock Mode)
```swift
@Test("Test player action handling")
func testPlayerActions() async {
    let engine = MockGameEngine(mode: .mock)

    await engine.submitPlayer(input: "explore")

    #expect(engine.log.count > 0)
    #expect(engine.submitPlayerCallCount == 1)
}
```

### Integration Tests (LLM Mode)
```swift
@Test("Test LLM narrative generation", .enabled(if: isLLMAvailable()))
func testLLMNarrative() async {
    let engine = MockGameEngine(mode: .llm)

    await engine.startNewGame(preferredType: .outdoor, usedNames: [])
    await engine.submitPlayer(input: "look around")

    #expect(engine.log.count > 1)
    #expect(engine.character != nil)

    // Verify LLM generated appropriate narrative
    let lastLog = engine.log.last?.content ?? ""
    #expect(lastLog.count > 20) // LLM should generate substantial text
}
```

### UI Development
```swift
// In ContentView.swift
#if DEBUG
@State private var engine: any GameEngine = MockGameEngine(mode: .mock)
#else
@State private var engine: any GameEngine = LLMGameEngine()
#endif
```

### SwiftUI Previews
```swift
#Preview("Mock Mode - Fast Iteration") {
    GameView(engine: MockGameEngine(mode: .mock))
}

#Preview("LLM Mode - Real Responses") {
    GameView(engine: MockGameEngine(mode: .llm))
}
```

## Features

### Mock Mode
- ✅ Instant responses (50-100ms)
- ✅ Pre-populated test data
- ✅ Deterministic behavior
- ✅ Call count tracking
- ✅ No LLM dependency
- ✅ Works in simulator

### LLM Mode
- ✅ Real LLM responses
- ✅ Same interface as mock
- ✅ Automatic state sync
- ✅ Full game engine features
- ✅ Test actual AI behavior
- ⚠️ Requires device/Mac with Apple Intelligence

## Best Practices

1. **Use Mock Mode for**:
   - Rapid UI iteration
   - Unit tests
   - CI/CD pipelines
   - Development without LLM access

2. **Use LLM Mode for**:
   - Integration tests
   - Validating prompt changes
   - QA testing
   - Testing edge cases

3. **Conditional Testing**:
```swift
@Test("LLM-specific test", .enabled(if: isLLMAvailable()))
func testWithLLM() async {
    // Only runs when LLM is available
}
```

4. **Test Isolation for LLM Tests**:
```swift
@Test("LLM integration test", .enabled(if: isLLMAvailable()))
func testLLMIntegration() async throws {
    // Add delay at start to ensure clean state
    try? await Task.sleep(for: .milliseconds(500))

    let engine = MockGameEngine(mode: .llm)
    await engine.startNewGame(preferredType: .outdoor, usedNames: [])

    // Continue with test...
}
```
⚠️ **Important**: LLM mode tests share `SystemLanguageModel.default` resource. Add 500ms delays at the start of LLM tests to prevent test interference when running full suite.

5. **Complete Game Initialization for LLM Tests**:
```swift
@MainActor
private func setupGameWithAdventure(engine: MockGameEngine, preferredType: AdventureType) async {
    await engine.startNewGame(preferredType: preferredType, usedNames: [])

    if engine.awaitingWorldContinue {
        await engine.continueNewGame(usedNames: [])
    }

    if engine.awaitingLocationSelection, let firstLocation = engine.worldState?.locations.first {
        await engine.submitPlayer(input: firstLocation.name)
    }
}

// Usage
@Test("Quest test", .enabled(if: isLLMAvailable()))
func testQuest() async throws {
    try? await Task.sleep(for: .milliseconds(500))
    let engine = MockGameEngine(mode: .llm)
    await setupGameWithAdventure(engine: engine, preferredType: .dungeon)
    // Now ready for quest testing
}
```

6. **Call Tracking**:
```swift
let engine = MockGameEngine(mode: .mock)
await engine.startNewGame(preferredType: .outdoor, usedNames: [])

#expect(engine.startNewGameCallCount == 1)
#expect(engine.lastSubmittedInput == nil)

await engine.submitPlayer(input: "test")
#expect(engine.submitPlayerCallCount == 1)
#expect(engine.lastSubmittedInput == "test")
```

## Architecture

```
MockGameEngine
├── Mode: .mock → Instant, deterministic responses
├── Mode: .llm  → Delegates to real LLMGameEngine
├── syncFromLLM() → Keeps state in sync
└── Call tracking → Verifies test assertions
```

All methods check `mode` and either:
- Execute fast mock logic (`.mock`)
- Delegate to `llmEngine` and sync state (`.llm`)
