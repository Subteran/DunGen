# Implementation Guide

## Overview

This guide provides step-by-step instructions for implementing the SCP-NCI (Structured Context Protocol with Narrative Continuity and Intelligence) system in DunGen.

## Prerequisites

- Xcode 15.0+
- Swift 5.9+
- iOS 18.0+ / macOS 15.0+
- Existing DunGen project at latest commit
- Test device: iPad Pro 11" (Momo) with iOS 26.0.1

## Implementation Strategy

### Approach: Phased Rollout with Feature Flags

The implementation uses a **phased, backward-compatible** approach:

1. New components added alongside existing code
2. Feature flags control which system is active
3. A/B testing validates improvements
4. Gradual migration of specialists
5. Old code removed only after full validation

### Feature Flag System

```swift
enum ContextSystem {
    case legacy  // Current string-based system
    case scp     // New Structured Context Protocol
}

class FeatureFlags {
    static var contextSystem: ContextSystem = .legacy
    static var enabledSpecialists: Set<SpecialistType> = []
    
    static func shouldUseSCP(for specialist: SpecialistType) -> Bool {
        contextSystem == .scp || enabledSpecialists.contains(specialist)
    }
}
```

---

## Phase 1: Foundation (Week 1) ⭐

**Goal:** Implement core data structures and state management

### Step 1.1: Create Data Models (Day 1)

#### File: `DunGen/Models/NarrativeModels.swift` (NEW)

```swift
import Foundation

// MARK: - Quest Narrative State

struct QuestNarrativeState: Codable, Equatable {
    let questId: String
    let type: QuestType
    let goal: String
    let location: String
    
    var currentEncounter: Int
    var totalEncounters: Int
    var stage: QuestStage
    
    var threads: [NarrativeThread]
    var chain: [CausalEvent]
    var locationState: LocationState
    var npcRelations: [String: NPCRelation]
    var knownClues: Set<String>
    var unlockedPaths: Set<String>
    
    var tension: Int  // 1-10
    var playerMorale: Int  // 1-10
    
    enum QuestStage: String, Codable {
        case intro
        case rising
        case climax
        case resolution
    }
    
    // Compact JSON representation
    func toCompactJSON() -> [String: Any] {
        [
            "q": [
                "id": questId,
                "t": type.compactCode,
                "g": goal,
                "st": stage.rawValue
            ],
            "th": threads.filter { !$0.resolved }.map { $0.toCompactJSON() },
            "ch": chain.suffix(3).map { $0.toCompactJSON() },
            "ls": locationState.toCompactJSON(),
            "npc": npcRelations.mapValues { $0.toCompactJSON() },
            "te": tension,
            "mo": playerMorale
        ]
    }
}

// MARK: - Narrative Thread

struct NarrativeThread: Codable, Equatable, Identifiable {
    let id: String
    let text: String
    let type: ThreadType
    let introduced: Int
    var resolved: Bool
    var priority: Int  // 1-10
    
    enum ThreadType: String, Codable {
        case clue
        case subplot
        case foreshadow
        case promise
        case mystery
    }
    
    func toCompactJSON() -> [String: Any] {
        [
            "i": id,
            "x": text,
            "p": priority,
            "r": resolved ? 1 : 0
        ]
    }
}

// MARK: - Causal Event

struct CausalEvent: Codable, Equatable {
    let event: String
    let cause: String?
    let consequence: String?
    let encounter: Int
    
    func toCompactJSON() -> [String: Any] {
        var json: [String: Any] = ["e": event]
        if let c = cause { json["c"] = c }
        if let cons = consequence { json["->"] = cons }
        return json
    }
}

// MARK: - Location State

struct LocationState: Codable, Equatable {
    var cleared: Set<String>
    var locked: Set<String>
    var discovered: Set<String>
    var destroyed: Set<String>
    var activeThreats: Set<String>
    
    func toCompactJSON() -> [String: Any] {
        [
            "clr": Array(cleared),
            "lck": Array(locked),
            "dis": Array(discovered),
            "dest": Array(destroyed),
            "thr": Array(activeThreats)
        ]
    }
}

// MARK: - NPC Relation

struct NPCRelation: Codable, Equatable {
    var relationship: Int  // -10 to +10
    var timesMet: Int
    var lastInteraction: String
    var promises: [String]
    var secrets: Set<String>
    
    func toCompactJSON() -> [String: Any] {
        [
            "r": relationship,
            "m": timesMet,
            "l": lastInteraction
        ]
    }
}

// MARK: - Quest Type Extension

extension QuestType {
    var compactCode: String {
        switch self {
        case .combat: return "cmb"
        case .retrieval: return "ret"
        case .escort: return "esc"
        case .investigation: return "inv"
        case .rescue: return "rsc"
        case .diplomatic: return "dip"
        }
    }
}
```

**Testing:**
```bash
xcodebuild build -scheme DunGen -destination 'platform=iOS,name=Momo'
```

### Step 1.2: Create State Manager (Day 2)

#### File: `DunGen/Managers/StateManager.swift` (NEW)

```swift
import Foundation
import OSLog

class StateManager {
    private let logger = Logger(subsystem: "DunGen", category: "StateManager")
    
    // Canonical narrative state
    private(set) var narrativeState: QuestNarrativeState?
    
    // MARK: - State Lifecycle
    
    func startQuest(
        questId: String,
        type: QuestType,
        goal: String,
        location: String,
        totalEncounters: Int
    ) {
        narrativeState = QuestNarrativeState(
            questId: questId,
            type: type,
            goal: goal,
            location: location,
            currentEncounter: 0,
            totalEncounters: totalEncounters,
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
        
        logger.info("Started quest: \(questId)")
    }
    
    func endQuest() {
        narrativeState = nil
        logger.info("Ended quest")
    }
    
    // MARK: - State Updates
    
    func incrementEncounter() {
        narrativeState?.currentEncounter += 1
        updateStage()
    }
    
    func addThread(_ thread: NarrativeThread) {
        narrativeState?.threads.append(thread)
        pruneThreads()
    }
    
    func resolveThread(id: String) {
        if let index = narrativeState?.threads.firstIndex(where: { $0.id == id }) {
            narrativeState?.threads[index].resolved = true
        }
    }
    
    func addCausalEvent(_ event: CausalEvent) {
        narrativeState?.chain.append(event)
    }
    
    func updateLocationState(_ update: (inout LocationState) -> Void) {
        guard var state = narrativeState else { return }
        update(&state.locationState)
        narrativeState = state
    }
    
    func updateNPCRelation(name: String, _ update: (inout NPCRelation) -> Void) {
        guard var state = narrativeState else { return }
        var relation = state.npcRelations[name] ?? NPCRelation(
            relationship: 0,
            timesMet: 0,
            lastInteraction: "",
            promises: [],
            secrets: []
        )
        update(&relation)
        state.npcRelations[name] = relation
        narrativeState = state
    }
    
    func adjustTension(by delta: Int) {
        guard var state = narrativeState else { return }
        state.tension = max(1, min(10, state.tension + delta))
        narrativeState = state
    }
    
    // MARK: - State Snapshots
    
    func getSnapshot(
        for specialist: SpecialistType,
        maxTokens: Int
    ) -> StateSnapshot {
        guard let state = narrativeState else {
            return StateSnapshot(tokenCount: 0, data: [:])
        }
        
        var snapshot = StateSnapshot(tokenCount: 0, data: [:])
        var usedTokens = 0
        
        // Get required fields for this specialist
        let tiers = getTiers(for: specialist)
        
        for tier in tiers {
            let tierData = buildTierData(tier: tier, state: state)
            let tierTokens = TokenEstimator.estimateTokens(from: tierData)
            
            if usedTokens + tierTokens <= maxTokens {
                snapshot.merge(tierData)
                usedTokens += tierTokens
            } else {
                logger.debug("Tier \(tier.rawValue) excluded (would exceed \(maxTokens) tokens)")
                break
            }
        }
        
        snapshot.tokenCount = usedTokens
        return snapshot
    }
    
    // MARK: - Private Helpers
    
    private func updateStage() {
        guard var state = narrativeState else { return }
        
        let progress = Double(state.currentEncounter) / Double(state.totalEncounters)
        
        let newStage: QuestNarrativeState.QuestStage
        switch progress {
        case 0..<0.3: newStage = .intro
        case 0.3..<0.7: newStage = .rising
        case 0.7..<0.95: newStage = .climax
        default: newStage = .resolution
        }
        
        if newStage != state.stage {
            state.stage = newStage
            narrativeState = state
            logger.info("Stage transition: \(newStage.rawValue)")
        }
    }
    
    private func pruneThreads() {
        guard var state = narrativeState else { return }
        
        // Keep only top 5 priority unresolved threads
        let activeThreads = state.threads.filter { !$0.resolved }
        if activeThreads.count > 5 {
            let sorted = activeThreads.sorted { $0.priority > $1.priority }
            let kept = sorted.prefix(5)
            let resolved = state.threads.filter { $0.resolved }
            state.threads = Array(kept) + resolved
            narrativeState = state
        }
    }
    
    private func getTiers(for specialist: SpecialistType) -> [ContextTier] {
        switch specialist {
        case .adventure:
            return [.critical, .narrative, .situation, .extended]
        case .encounter:
            return [.critical]
        case .npc:
            return [.critical, .narrative]
        case .monsters:
            return [.critical]
        default:
            return [.critical, .situation]
        }
    }
    
    private func buildTierData(tier: ContextTier, state: QuestNarrativeState) -> [String: Any] {
        switch tier {
        case .critical:
            return ["stage": state.stage.rawValue]
            
        case .narrative:
            return state.toCompactJSON()
            
        case .situation:
            return [
                "q": ["goal": state.goal, "cur": state.currentEncounter, "tot": state.totalEncounters],
                "loc": state.location
            ]
            
        case .extended:
            return [:]  // Additional context if needed
        }
    }
}

// MARK: - Supporting Types

enum ContextTier: String {
    case critical
    case narrative
    case situation
    case extended
}

struct StateSnapshot {
    var tokenCount: Int
    var data: [String: Any]
    
    mutating func merge(_ newData: [String: Any]) {
        data.merge(newData) { _, new in new }
    }
}
```

**Testing:**
```swift
// Add to DunGenTests/StateManagerTests.swift
@Test("StateManager initializes quest correctly")
func testQuestInitialization() {
    let manager = StateManager()
    
    manager.startQuest(
        questId: "test_001",
        type: .retrieval,
        goal: "Find the amulet",
        location: "dungeon",
        totalEncounters: 8
    )
    
    #expect(manager.narrativeState != nil)
    #expect(manager.narrativeState?.questId == "test_001")
    #expect(manager.narrativeState?.stage == .intro)
    #expect(manager.narrativeState?.tension == 2)
}
```

### Step 1.3: Create Token Budget Configuration (Day 3)

#### File: `DunGen/Managers/SpecialistBudget.swift` (NEW)

```swift
import Foundation

struct SpecialistBudget {
    let maxTotal: Int = 4096
    let specialist: SpecialistType
    let instructionTokens: Int
    let responseBuffer: Int
    let safetyMargin: Int = 50
    
    var availableForState: Int {
        maxTotal - instructionTokens - responseBuffer - safetyMargin
    }
    
    var description: String {
        """
        [\(specialist)] Budget:
          Total: \(maxTotal)
          Instructions: \(instructionTokens)
          Response: \(responseBuffer)
          Safety: \(safetyMargin)
          Available: \(availableForState)
        """
    }
    
    static let budgets: [SpecialistType: SpecialistBudget] = [
        .adventure: SpecialistBudget(
            specialist: .adventure,
            instructionTokens: 55,  // New compressed schema
            responseBuffer: 120     // Strict 2-4 sentence limit
        ),
        .encounter: SpecialistBudget(
            specialist: .encounter,
            instructionTokens: 25,
            responseBuffer: 50
        ),
        .npc: SpecialistBudget(
            specialist: .npc,
            instructionTokens: 35,
            responseBuffer: 100
        ),
        .monsters: SpecialistBudget(
            specialist: .monsters,
            instructionTokens: 30,
            responseBuffer: 80
        ),
        .world: SpecialistBudget(
            specialist: .world,
            instructionTokens: 40,
            responseBuffer: 100
        ),
        .character: SpecialistBudget(
            specialist: .character,
            instructionTokens: 50,
            responseBuffer: 150
        ),
        .abilities: SpecialistBudget(
            specialist: .abilities,
            instructionTokens: 35,
            responseBuffer: 100
        ),
        .spells: SpecialistBudget(
            specialist: .spells,
            instructionTokens: 35,
            responseBuffer: 100
        ),
        .prayers: SpecialistBudget(
            specialist: .prayers,
            instructionTokens: 35,
            responseBuffer: 100
        )
    ]
}

// MARK: - Token Breakdown

struct TokenBreakdown {
    let system: Int
    let state: Int
    let response: Int
    let total: Int
    
    var percentage: Int {
        Int((Double(total) / 4096.0) * 100)
    }
    
    var description: String {
        """
        Token Breakdown:
          System: \(system)
          State: \(state)
          Response: \(response)
          Total: \(total)/4096 (\(percentage)%)
        """
    }
}
```

#### File: `DunGen/Resources/specialist_budgets.json` (NEW)

```json
{
  "adventure": {
    "instructionTokens": 55,
    "responseBuffer": 120,
    "maxPromptTokens": 3871
  },
  "encounter": {
    "instructionTokens": 25,
    "responseBuffer": 50,
    "maxPromptTokens": 3971
  },
  "npc": {
    "instructionTokens": 35,
    "responseBuffer": 100,
    "maxPromptTokens": 3911
  },
  "monsters": {
    "instructionTokens": 30,
    "responseBuffer": 80,
    "maxPromptTokens": 3936
  },
  "world": {
    "instructionTokens": 40,
    "responseBuffer": 100,
    "maxPromptTokens": 3906
  },
  "character": {
    "instructionTokens": 50,
    "responseBuffer": 150,
    "maxPromptTokens": 3846
  },
  "abilities": {
    "instructionTokens": 35,
    "responseBuffer": 100,
    "maxPromptTokens": 3911
  },
  "spells": {
    "instructionTokens": 35,
    "responseBuffer": 100,
    "maxPromptTokens": 3911
  },
  "prayers": {
    "instructionTokens": 35,
    "responseBuffer": 100,
    "maxPromptTokens": 3911
  }
}
```

**Testing:**
```swift
@Test("Budget calculations are correct")
func testBudgetCalculations() {
    let budget = SpecialistBudget.budgets[.adventure]!
    
    #expect(budget.availableForState == 3871)
    #expect(budget.maxTotal == 4096)
}
```

### Step 1.4: Update TokenEstimator (Day 3)

#### File: `DunGen/Utilities/TokenEstimator.swift` (MODIFY)

Add these methods:

```swift
// Add to existing TokenEstimator

extension TokenEstimator {
    /// Estimate tokens from JSON dictionary
    static func estimateTokens(from json: [String: Any]) -> Int {
        let jsonString = jsonToString(json)
        return estimateTokens(from: jsonString)
    }
    
    /// Convert JSON to compact string
    private static func jsonToString(_ json: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
    
    /// Analyze token distribution in context
    static func analyzeContext(
        system: String,
        state: [String: Any],
        response: Int
    ) -> ContextAnalysis {
        let systemTokens = estimateTokens(from: system)
        let stateTokens = estimateTokens(from: state)
        let total = systemTokens + stateTokens + response + 50
        
        return ContextAnalysis(
            systemTokens: systemTokens,
            stateTokens: stateTokens,
            responseTokens: response,
            safetyMargin: 50,
            total: total,
            percentage: Double(total) / 4096.0
        )
    }
}

struct ContextAnalysis {
    let systemTokens: Int
    let stateTokens: Int
    let responseTokens: Int
    let safetyMargin: Int
    let total: Int
    let percentage: Double
    
    var isOverBudget: Bool {
        total > 4096
    }
    
    var isNearLimit: Bool {
        percentage > 0.85
    }
    
    var description: String {
        """
        Context Analysis:
          System: \(systemTokens)
          State: \(stateTokens)
          Response: \(responseTokens)
          Safety: \(safetyMargin)
          Total: \(total)/4096 (\(String(format: "%.1f", percentage * 100))%)
          Status: \(isOverBudget ? "❌ OVER" : isNearLimit ? "⚠️ NEAR" : "✅ OK")
        """
    }
}
```

### Phase 1 Checklist

- [ ] Created `NarrativeModels.swift` with all data structures
- [ ] Created `StateManager.swift` with state lifecycle
- [ ] Created `SpecialistBudget.swift` with token budgets
- [ ] Created `specialist_budgets.json` configuration
- [ ] Updated `TokenEstimator.swift` with JSON support
- [ ] All Phase 1 code compiles successfully
- [ ] Unit tests pass for new components
- [ ] Documented all public APIs

**Validation:**
```bash
# Build
xcodebuild build -scheme DunGen -destination 'platform=iOS,name=Momo'

# Run Phase 1 tests
xcodebuild test -scheme DunGen -destination 'platform=iOS,name=Momo' \
  -only-testing:DunGenTests/StateManagerTests
```

---

## Phase 2: Context Assembly (Week 2)

**Goal:** Implement tiered context assembly with JSON schemas

[Continue with Phase 2 implementation steps...]

### Step 2.1: Create Schema Manager (Day 4)

[Detailed implementation steps continue...]

---

## Integration Checklist

After all phases are complete:

- [ ] Feature flags configured
- [ ] Legacy system still functional
- [ ] A/B testing setup complete
- [ ] Metrics collection enabled
- [ ] Debug UI accessible
- [ ] All tests passing
- [ ] Performance benchmarks met
- [ ] Documentation updated

---

## Troubleshooting

### Common Issues

**Issue:** Token budget exceeded
**Solution:** Check `ContextAnalysis.description` output, reduce tier usage

**Issue:** Validation errors
**Solution:** Enable `NarrativeDebugView`, inspect state transitions

**Issue:** Tests fail intermittently
**Solution:** Add 500ms delay at test start (LLM resource sharing)

---

## Next Steps

After Phase 1 completion:
1. Review Phase 1 code with team
2. Run 10+ test quests to validate
3. Check metrics for token reduction
4. Proceed to Phase 2

**Continue to:** `MIGRATION_GUIDE.md` for integration details
