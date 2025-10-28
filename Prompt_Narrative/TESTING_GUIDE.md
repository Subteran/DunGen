# Testing Guide

## Overview

This guide covers testing strategies for the SCP-NCI narrative system, including unit tests, integration tests, consistency tests, and performance benchmarks.

## Test Structure

```
DunGenTests/
├── Narrative/
│   ├── StateManagerTests.swift
│   ├── NarrativeAnalyzerTests.swift
│   ├── ConsistencyValidatorTests.swift
│   ├── ContextAssemblerTests.swift
│   └── StateLoggerTests.swift
├── Integration/
│   ├── FullQuestNarrativeTests.swift
│   ├── ConsistencyFlowTests.swift
│   └── TokenBudgetTests.swift
└── Performance/
    └── NarrativePerformanceTests.swift
```

---

## Unit Tests

### StateManager Tests

```swift
import Testing
@testable import DunGen

@Suite("StateManager Tests")
struct StateManagerTests {
    
    @Test("Quest initialization creates valid state")
    func testQuestInitialization() {
        let manager = StateManager()
        
        manager.startQuest(
            questId: "test_001",
            type: .retrieval,
            goal: "Find the stolen amulet",
            location: "bandit_hideout",
            totalEncounters: 8
        )
        
        let state = manager.narrativeState
        
        #expect(state != nil)
        #expect(state?.questId == "test_001")
        #expect(state?.type == .retrieval)
        #expect(state?.stage == .intro)
        #expect(state?.tension == 2)
        #expect(state?.threads.isEmpty == true)
        #expect(state?.chain.isEmpty == true)
    }
    
    @Test("Thread management maintains max 5 active")
    func testThreadPruning() {
        let manager = StateManager()
        manager.startQuest(
            questId: "test_002",
            type: .combat,
            goal: "Defeat the boss",
            location: "dungeon",
            totalEncounters: 8
        )
        
        // Add 7 threads
        for i in 1...7 {
            manager.addThread(NarrativeThread(
                id: "t\(i)",
                text: "Thread \(i)",
                type: .clue,
                introduced: 1,
                resolved: false,
                priority: i
            ))
        }
        
        // Should keep only top 5 priority
        let activeThreads = manager.narrativeState?.threads.filter { !$0.resolved }
        #expect(activeThreads?.count == 5)
        
        // Verify highest priorities kept
        let priorities = activeThreads?.map { $0.priority }.sorted(by: >) ?? []
        #expect(priorities == [7, 6, 5, 4, 3])
    }
    
    @Test("Stage updates based on progress")
    func testStageProgression() {
        let manager = StateManager()
        manager.startQuest(
            questId: "test_003",
            type: .escort,
            goal: "Escort merchant",
            location: "road",
            totalEncounters: 10
        )
        
        // Intro (0-29%)
        manager.incrementEncounter()
        #expect(manager.narrativeState?.stage == .intro)
        
        // Rising (30-69%)
        manager.narrativeState?.currentEncounter = 4
        manager.incrementEncounter()
        #expect(manager.narrativeState?.stage == .rising)
        
        // Climax (70-94%)
        manager.narrativeState?.currentEncounter = 7
        manager.incrementEncounter()
        #expect(manager.narrativeState?.stage == .climax)
        
        // Resolution (95-100%)
        manager.narrativeState?.currentEncounter = 10
        manager.incrementEncounter()
        #expect(manager.narrativeState?.stage == .resolution)
    }
    
    @Test("Snapshot generation respects token limits")
    func testSnapshotTokenLimits() {
        let manager = StateManager()
        manager.startQuest(
            questId: "test_004",
            type: .investigation,
            goal: "Solve the mystery",
            location: "mansion",
            totalEncounters: 8
        )
        
        // Add threads, chain, NPCs
        manager.addThread(NarrativeThread(
            id: "t1",
            text: "Mysterious footprints",
            type: .clue,
            introduced: 1,
            resolved: false,
            priority: 7
        ))
        
        manager.addCausalEvent(CausalEvent(
            event: "found_clue",
            cause: nil,
            consequence: "investigate_library",
            encounter: 1
        ))
        
        // Get snapshot with small limit
        let snapshot = manager.getSnapshot(for: .adventure, maxTokens: 50)
        
        #expect(snapshot.tokenCount <= 50)
        #expect(snapshot.data.keys.count > 0)
    }
}
```

### NarrativeAnalyzer Tests

```swift
@Suite("NarrativeAnalyzer Tests")
struct NarrativeAnalyzerTests {
    
    let analyzer = NarrativeAnalyzer()
    
    @Test("Causal coherence detects violations")
    func testCausalViolation() {
        var state = createTestState()
        
        // Add chain with missing cause
        state.chain = [
            CausalEvent(event: "found_key", cause: nil, consequence: "can_open_gate", encounter: 1),
            CausalEvent(event: "entered_vault", cause: "defeated_boss", consequence: nil, encounter: 2)
        ]
        
        let score = analyzer.analyzeConsistency(
            currentState: state,
            previousState: nil,
            newNarration: "You enter the vault",
            newEvent: state.chain.last
        )
        
        #expect(score.breakdown.causalCoherence < 0.8)
        #expect(score.issues.contains { $0.type == .causalViolation })
    }
    
    @Test("Spatial consistency detects locked area access")
    func testSpatialViolation() {
        var state = createTestState()
        state.locationState.locked.insert("vault")
        
        let narration = "You walk into the vault and see treasure"
        
        let score = analyzer.analyzeConsistency(
            currentState: state,
            previousState: nil,
            newNarration: narration,
            newEvent: nil
        )
        
        #expect(score.breakdown.spatialConsistency < 0.8)
        #expect(score.issues.contains { $0.type == .spatialViolation })
    }
    
    @Test("Thread resolution tracks aging")
    func testThreadAging() {
        var state = createTestState()
        state.currentEncounter = 10
        state.totalEncounters = 12
        
        state.threads = [
            NarrativeThread(
                id: "t1",
                text: "Find the artifact",
                type: .promise,
                introduced: 2,
                resolved: false,
                priority: 9
            )
        ]
        
        let score = analyzer.analyzeConsistency(
            currentState: state,
            previousState: nil,
            newNarration: "You continue exploring",
            newEvent: nil
        )
        
        #expect(score.breakdown.threadResolution < 0.9)
        #expect(score.issues.contains { $0.type == .unresolvedThread })
    }
    
    @Test("NPC consistency detects relationship violations")
    func testNPCInconsistency() {
        var state = createTestState()
        state.npcRelations["Guard"] = NPCRelation(
            relationship: -8,
            timesMet: 2,
            lastInteraction: "threatened",
            promises: [],
            secrets: []
        )
        
        let narration = "The guard smiles warmly and welcomes you"
        
        let score = analyzer.analyzeConsistency(
            currentState: state,
            previousState: nil,
            newNarration: narration,
            newEvent: nil
        )
        
        #expect(score.breakdown.npcConsistency < 0.7)
        #expect(score.issues.contains { $0.type == .npcInconsistency })
    }
    
    @Test("Tension arc detects inversions")
    func testTensionInversion() {
        let prevState = createTestState()
        prevState.tension = 7
        prevState.stage = .climax
        
        var currState = prevState
        currState.tension = 4  // Dropped!
        currState.currentEncounter = prevState.currentEncounter + 1
        
        let score = analyzer.analyzeConsistency(
            currentState: currState,
            previousState: prevState,
            newNarration: "Things calm down",
            newEvent: nil
        )
        
        #expect(score.breakdown.tensionArc < 0.8)
        #expect(score.issues.contains { $0.type == .tensionInversion })
    }
    
    @Test("Quest alignment detects drift")
    func testQuestDrift() {
        var state = createTestState()
        state.goal = "Find the stolen crown"
        state.stage = .climax
        
        let narration = "You wander through empty halls"  // No mention of crown
        
        let score = analyzer.analyzeConsistency(
            currentState: state,
            previousState: nil,
            newNarration: narration,
            newEvent: nil
        )
        
        #expect(score.breakdown.questAlignment < 0.9)
        #expect(score.issues.contains { $0.type == .questDrift })
    }
    
    // Helper
    private func createTestState() -> QuestNarrativeState {
        QuestNarrativeState(
            questId: "test_001",
            type: .retrieval,
            goal: "Find the amulet",
            location: "dungeon",
            currentEncounter: 3,
            totalEncounters: 8,
            stage: .rising,
            threads: [],
            chain: [],
            locationState: LocationState(
                cleared: [],
                locked: [],
                discovered: [],
                destroyed: [],
                activeThreats: []
            ),
            npcRelations: [:],
            knownClues: [],
            unlockedPaths: [],
            tension: 5,
            playerMorale: 7
        )
    }
}
```

### ConsistencyValidator Tests

```swift
@Suite("ConsistencyValidator Tests")
struct ConsistencyValidatorTests {
    
    let validator = ConsistencyValidator()
    
    @Test("Pre-flight catches state corruption")
    func testPreFlightStateCorruption() {
        var state = createTestState()
        state.tension = 15  // Invalid!
        
        let context = createTestContext(state: state)
        let result = validator.validateBeforeLLMCall(state: state, context: context)
        
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.type == .stateCorruption })
    }
    
    @Test("Pre-flight detects token overflow")
    func testPreFlightTokenOverflow() {
        let state = createTestState()
        
        var context = createTestContext(state: state)
        context.tokenBreakdown = TokenBreakdown(
            system: 100,
            state: 4000,
            response: 200,
            total: 4300  // Over 4096!
        )
        
        let result = validator.validateBeforeLLMCall(state: state, context: context)
        
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.type == .tokenOverflow })
    }
    
    @Test("Post-flight catches format violations")
    func testPostFlightFormatViolation() {
        let state = createTestState()
        
        let response = AdventureTurn(
            narration: String(repeating: "a", count: 500),  // Too long!
            adventureProgress: nil,  // Missing!
            suggestedActions: [],
            causalEvent: nil
        )
        
        let result = validator.validateAfterLLMResponse(
            previousState: nil,
            newState: state,
            narration: response.narration,
            response: response
        )
        
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.type == .formatViolation })
    }
    
    @Test("Post-flight detects third-person narration")
    func testPostFlightThirdPerson() {
        let state = createTestState()
        
        let response = AdventureTurn(
            narration: "The hero walks into the room",
            adventureProgress: "Progress",
            suggestedActions: ["Action"],
            causalEvent: nil
        )
        
        let result = validator.validateAfterLLMResponse(
            previousState: nil,
            newState: state,
            narration: response.narration,
            response: response
        )
        
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.type == .formatViolation })
    }
    
    // Helpers
    private func createTestState() -> QuestNarrativeState {
        QuestNarrativeState(
            questId: "test_001",
            type: .combat,
            goal: "Defeat boss",
            location: "dungeon",
            currentEncounter: 1,
            totalEncounters: 8,
            stage: .intro,
            threads: [],
            chain: [],
            locationState: LocationState(
                cleared: [],
                locked: [],
                discovered: [],
                destroyed: [],
                activeThreats: []
            ),
            npcRelations: [:],
            knownClues: [],
            unlockedPaths: [],
            tension: 2,
            playerMorale: 7
        )
    }
    
    private func createTestContext(state: QuestNarrativeState) -> AssembledContext {
        AssembledContext(
            specialist: "adventure",
            stateJSON: "{}",
            tokenBreakdown: TokenBreakdown(
                system: 55,
                state: 150,
                response: 120,
                total: 375
            )
        )
    }
}
```

---

## Integration Tests

### Full Quest Narrative Test

```swift
@Suite("Full Quest Narrative Integration")
struct FullQuestNarrativeTests {
    
    @Test("Quest maintains consistency throughout", .enabled(if: isLLMAvailable()))
    func testFullQuestConsistency() async throws {
        try? await Task.sleep(for: .milliseconds(500))  // LLM isolation
        
        let engine = MockGameEngine(mode: .llm)
        let stateLogger = StateLogger()
        let analyzer = NarrativeAnalyzer()
        
        stateLogger.startQuestLog(questId: "integration_test_001")
        
        // Start quest
        await engine.startNewGame(preferredType: .village, usedNames: [])
        
        var previousState: QuestNarrativeState? = nil
        var allScores: [ConsistencyScore] = []
        
        // Run 8 encounters
        for encounter in 1...8 {
            await engine.submitPlayer(input: "explore")
            
            let currentState = engine.getNarrativeState()
            let narration = engine.lastNarration
            
            let score = analyzer.analyzeConsistency(
                currentState: currentState,
                previousState: previousState,
                newNarration: narration,
                newEvent: currentState.chain.last
            )
            
            allScores.append(score)
            
            // Log issues
            for issue in score.issues where issue.severity == .critical {
                print("[CRITICAL] Encounter \(encounter): \(issue.description)")
            }
            
            previousState = currentState
        }
        
        let report = stateLogger.finalizeQuestLog()
        
        // Assertions
        #expect(report != nil)
        #expect(report!.averageConsistencyScore > 0.70)
        #expect(report!.criticalIssues.count == 0)
        #expect(report!.averageTokenUsage < 300)
        
        print(report!.summary)
    }
}
```

### Token Budget Integration Test

```swift
@Suite("Token Budget Integration")
struct TokenBudgetTests {
    
    @Test("Context assembly never exceeds budget", .enabled(if: isLLMAvailable()))
    func testContextBudgetCompliance() async throws {
        let engine = MockGameEngine(mode: .llm)
        let assembler = ContextAssembler(stateManager: engine.stateManager)
        
        await engine.startNewGame(preferredType: .dungeon, usedNames: [])
        
        // Run multiple turns, checking budget each time
        for turn in 1...10 {
            await engine.submitPlayer(input: "explore")
            
            let budget = SpecialistBudget.budgets[.adventure]!
            let context = assembler.assembleContext(
                for: .adventure,
                maxTokens: budget.availableForState
            )
            
            #expect(context.tokenBreakdown.total <= 4096)
            
            print("Turn \(turn): \(context.tokenBreakdown.total)/4096 tokens")
        }
    }
}
```

---

## Performance Tests

### Performance Benchmarks

```swift
@Suite("Narrative Performance")
struct NarrativePerformanceTests {
    
    @Test("Context assembly completes quickly")
    func testContextAssemblyPerformance() async {
        let manager = StateManager()
        let assembler = ContextAssembler(stateManager: manager)
        
        manager.startQuest(
            questId: "perf_001",
            type: .retrieval,
            goal: "Test",
            location: "test",
            totalEncounters: 8
        )
        
        let start = Date()
        
        for _ in 1...100 {
            _ = assembler.assembleContext(for: .adventure, maxTokens: 3871)
        }
        
        let elapsed = Date().timeIntervalSince(start)
        let avgTime = elapsed / 100.0
        
        #expect(avgTime < 0.05)  // 50ms average
        
        print("Context assembly: \(String(format: "%.2f", avgTime * 1000))ms avg")
    }
    
    @Test("Consistency analysis completes quickly")
    func testAnalysisPerformance() {
        let analyzer = NarrativeAnalyzer()
        let state = createComplexState()
        
        let start = Date()
        
        for _ in 1...100 {
            _ = analyzer.analyzeConsistency(
                currentState: state,
                previousState: nil,
                newNarration: "Test narration",
                newEvent: nil
            )
        }
        
        let elapsed = Date().timeIntervalSince(start)
        let avgTime = elapsed / 100.0
        
        #expect(avgTime < 0.02)  // 20ms average
        
        print("Consistency analysis: \(String(format: "%.2f", avgTime * 1000))ms avg")
    }
    
    private func createComplexState() -> QuestNarrativeState {
        var state = QuestNarrativeState(
            questId: "perf_001",
            type: .investigation,
            goal: "Solve mystery",
            location: "mansion",
            currentEncounter: 5,
            totalEncounters: 10,
            stage: .rising,
            threads: [],
            chain: [],
            locationState: LocationState(
                cleared: ["entrance", "hall", "study"],
                locked: ["vault", "tower"],
                discovered: ["cellar", "attic"],
                destroyed: ["bridge"],
                activeThreats: ["boss_room"]
            ),
            npcRelations: [:],
            knownClues: [],
            unlockedPaths: [],
            tension: 6,
            playerMorale: 7
        )
        
        // Add threads
        for i in 1...5 {
            state.threads.append(NarrativeThread(
                id: "t\(i)",
                text: "Thread \(i)",
                type: .clue,
                introduced: i,
                resolved: false,
                priority: i + 3
            ))
        }
        
        // Add chain
        for i in 1...8 {
            state.chain.append(CausalEvent(
                event: "event_\(i)",
                cause: i > 1 ? "event_\(i-1)" : nil,
                consequence: "event_\(i+1)",
                encounter: i
            ))
        }
        
        // Add NPCs
        state.npcRelations["Butler"] = NPCRelation(
            relationship: 5,
            timesMet: 2,
            lastInteraction: "helpful",
            promises: [],
            secrets: []
        )
        
        state.npcRelations["Guard"] = NPCRelation(
            relationship: -3,
            timesMet: 1,
            lastInteraction: "suspicious",
            promises: [],
            secrets: []
        )
        
        return state
    }
}
```

---

## Running Tests

### All Tests
```bash
xcodebuild test -scheme DunGen -destination 'platform=iOS,name=Momo'
```

### Specific Suite
```bash
xcodebuild test -scheme DunGen -destination 'platform=iOS,name=Momo' \
  -only-testing:DunGenTests/StateManagerTests
```

### Single Test
```bash
xcodebuild test -scheme DunGen -destination 'platform=iOS,name=Momo' \
  -only-testing:DunGenTests/StateManagerTests/testQuestInitialization
```

### Performance Tests Only
```bash
xcodebuild test -scheme DunGen -destination 'platform=iOS,name=Momo' \
  -only-testing:DunGenTests/NarrativePerformanceTests
```

---

## Test Coverage Goals

| Component | Target Coverage | Priority |
|-----------|----------------|----------|
| StateManager | 90%+ | High |
| NarrativeAnalyzer | 85%+ | High |
| ConsistencyValidator | 85%+ | High |
| ContextAssembler | 80%+ | High |
| StateLogger | 75%+ | Medium |
| MetricsCollector | 70%+ | Medium |

---

## Continuous Testing

### Pre-Commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running narrative system tests..."
xcodebuild test -scheme DunGen -destination 'platform=iOS,name=Momo' \
  -only-testing:DunGenTests/StateManagerTests \
  -only-testing:DunGenTests/NarrativeAnalyzerTests

if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi
```

### CI Pipeline

```yaml
# .github/workflows/narrative-tests.yml
name: Narrative System Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Unit Tests
        run: xcodebuild test -scheme DunGen -destination 'platform=iOS Simulator,name=iPad Pro (11-inch)'
      - name: Upload Test Results
        uses: actions/upload-artifact@v2
        with:
          name: test-results
          path: test-results/
```

---

## Test Data Management

### Fixtures

Create test fixtures for common scenarios:

```swift
enum TestFixtures {
    static func retrievalQuest() -> QuestNarrativeState {
        // Standard retrieval quest state
    }
    
    static func combatQuest() -> QuestNarrativeState {
        // Standard combat quest state
    }
    
    static func complexState() -> QuestNarrativeState {
        // State with threads, chain, NPCs, etc.
    }
}
```

### Snapshot Files

Save baseline quest reports for regression testing:

```
DunGenTests/Snapshots/
├── baseline_retrieval_quest.json
├── baseline_combat_quest.json
└── baseline_investigation_quest.json
```

---

## Debugging Failed Tests

### Common Issues

**Issue: LLM tests fail intermittently**
```swift
// Solution: Add delay at test start
try? await Task.sleep(for: .milliseconds(500))
```

**Issue: Token budget exceeded**
```swift
// Debug: Check token breakdown
print(context.tokenBreakdown.description)
```

**Issue: Consistency score unexpectedly low**
```swift
// Debug: Inspect issues
for issue in score.issues {
    print("[\(issue.severity)] \(issue.type): \(issue.description)")
}
```

---

## Next Steps

After implementing tests:

1. Achieve 85%+ coverage on core components
2. Run full integration tests on 10+ quests
3. Benchmark performance meets targets
4. Document any test failures or edge cases
5. Proceed to production rollout
