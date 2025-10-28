# Migration Guide

## Overview

This guide provides step-by-step instructions for migrating from the legacy narrative system to SCP-NCI while maintaining backward compatibility.

## Migration Strategy

### Principles

1. **Zero Downtime** - New system coexists with legacy
2. **Gradual Rollout** - Migrate specialists one at a time
3. **Feature Flags** - Control which system is active
4. **Easy Rollback** - Can revert to legacy at any time
5. **Data Compatibility** - Existing saves work with both systems

---

## Phase 1: Add New Components (Week 1)

### Step 1: Add Data Models

Create `DunGen/Models/NarrativeModels.swift`:

```swift
// Add all new data structures
// See IMPLEMENTATION_GUIDE.md Step 1.1
```

**Validation:**
```bash
xcodebuild build -scheme DunGen -destination 'platform=iOS,name=Momo'
```

### Step 2: Add StateManager

Create `DunGen/Managers/StateManager.swift`:

```swift
// See IMPLEMENTATION_GUIDE.md Step 1.2
```

### Step 3: Add SpecialistBudget

Create `DunGen/Managers/SpecialistBudget.swift`:

```swift
// See IMPLEMENTATION_GUIDE.md Step 1.3
```

### Step 4: Update TokenEstimator

Modify existing `DunGen/Utilities/TokenEstimator.swift`:

```swift
extension TokenEstimator {
    // Add JSON token estimation
    static func estimateTokens(from json: [String: Any]) -> Int {
        // Implementation
    }
}
```

**Validation:**
- All existing tests still pass
- New components compile
- No runtime errors

---

## Phase 2: Add Feature Flag System (Week 1)

### Step 1: Create FeatureFlags

Create `DunGen/Utilities/FeatureFlags.swift`:

```swift
import Foundation

enum ContextSystem {
    case legacy  // Current system
    case scp     // New SCP-NCI system
}

class FeatureFlags {
    // Global flag - controls default behavior
    static var contextSystem: ContextSystem = .legacy
    
    // Per-specialist overrides
    static var enabledSpecialists: Set<SpecialistType> = []
    
    // Check if should use new system for specialist
    static func shouldUseSCP(for specialist: SpecialistType) -> Bool {
        // If global flag is SCP, use new system
        if contextSystem == .scp {
            return true
        }
        
        // Otherwise check per-specialist override
        return enabledSpecialists.contains(specialist)
    }
    
    // Enable new system for specific specialists
    static func enableSCP(for specialists: SpecialistType...) {
        enabledSpecialists.formUnion(specialists)
    }
    
    // Disable new system for specific specialists
    static func disableSCP(for specialists: SpecialistType...) {
        enabledSpecialists.subtract(specialists)
    }
    
    // Enable globally
    static func enableGlobalSCP() {
        contextSystem = .scp
    }
    
    // Disable globally (rollback)
    static func disableGlobalSCP() {
        contextSystem = .legacy
        enabledSpecialists.removeAll()
    }
}
```

### Step 2: Add Dual-Path Methods to LLMGameEngine

Modify `DunGen/LLM/LLMGameEngine.swift`:

```swift
class LLMGameEngine {
    // ... existing properties ...
    
    // NEW: SCP-NCI components
    private let stateManager = StateManager()
    private var contextAssembler: ContextAssembler?
    private let validator = ConsistencyValidator()
    private let stateLogger = StateLogger()
    private let metricsCollector = MetricsCollector()
    
    // NEW: Dual-path advanceScene
    func advanceScene() async {
        if FeatureFlags.shouldUseSCP(for: .adventure) {
            await advanceSceneSCP()
        } else {
            await advanceSceneLegacy()
        }
    }
    
    // NEW: SCP-NCI implementation
    private func advanceSceneSCP() async {
        // See INTEGRATION.md for full implementation
        logger.info("Using SCP-NCI system")
        
        // 1. Validate pre-flight
        // 2. Assemble context
        // 3. Call LLM
        // 4. Validate post-flight
        // 5. Update state
        // 6. Log transition
    }
    
    // EXISTING: Legacy implementation (renamed)
    private func advanceSceneLegacy() async {
        // Existing implementation unchanged
        logger.info("Using legacy system")
        
        // ... existing code ...
    }
}
```

**Validation:**
- Game still works with `FeatureFlags.contextSystem = .legacy`
- No functionality broken

---

## Phase 3: Implement Context Assembly (Week 2)

### Step 1: Create ContextAssembler

Create `DunGen/Managers/ContextAssembler.swift`:

```swift
class ContextAssembler {
    private let stateManager: StateManager
    private let schemaManager: SchemaManager
    
    func assembleContext(
        for specialist: SpecialistType,
        maxTokens: Int
    ) -> AssembledContext {
        // Implementation
    }
}
```

### Step 2: Create SchemaManager

Create `DunGen/Managers/SchemaManager.swift`:

```swift
class SchemaManager {
    func getSchema(for specialist: SpecialistType) -> InstructionSchema {
        // Load from JSON files
    }
}
```

### Step 3: Create Instruction Schemas

Create JSON files in `DunGen/Resources/instruction_schemas/`:
- `adventure_schema.json`
- `encounter_schema.json`
- `npc_schema.json`
- etc.

**Validation:**
- Context assembly produces valid JSON
- Token budgets respected
- Schemas load correctly

---

## Phase 4: Test Single Specialist (Week 2-3)

### Step 1: Enable Encounter Specialist

```swift
// In AppDelegate or game initialization
FeatureFlags.enableSCP(for: .encounter)
```

**Why Encounter first?**
- Simplest specialist (2 fields)
- Lowest risk
- Easy to validate

### Step 2: Run Comparison Tests

```swift
@Test("Compare encounter outputs")
func testEncounterComparison() async {
    // Run with legacy
    FeatureFlags.contextSystem = .legacy
    let legacyOutput = await generateEncounter()
    
    // Run with SCP
    FeatureFlags.enableSCP(for: .encounter)
    let scpOutput = await generateEncounter()
    
    // Compare
    #expect(legacyOutput.encounterType == scpOutput.encounterType)
    #expect(legacyOutput.difficulty == scpOutput.difficulty)
}
```

### Step 3: Monitor Metrics

```swift
// Check token usage
print("Legacy tokens: \(legacyTokens)")
print("SCP tokens: \(scpTokens)")
print("Savings: \(String(format: "%.1f", (1 - Double(scpTokens)/Double(legacyTokens)) * 100))%")
```

### Step 4: Rollback if Issues

```swift
// If problems detected
FeatureFlags.disableSCP(for: .encounter)
// Game continues with legacy system
```

**Validation:**
- Encounter generation works correctly
- Token usage reduced
- No gameplay regressions
- Easy rollback confirmed

---

## Phase 5: Migrate Remaining Specialists (Week 3-4)

### Recommended Order

1. ✅ Encounter (simplest)
2. NPC (medium complexity)
3. Monsters (code-based, low risk)
4. Adventure (most complex, highest impact)
5. World
6. Character
7. Abilities/Spells/Prayers

### Migration Template

For each specialist:

```swift
// 1. Enable
FeatureFlags.enableSCP(for: .npc)

// 2. Test for 10+ quests
for i in 1...10 {
    await runFullQuest()
    checkMetrics()
}

// 3. Compare to legacy
let comparison = compareToLegacy()
print(comparison.summary)

// 4. If good, keep enabled
// 5. If issues, rollback and fix
if hasIssues {
    FeatureFlags.disableSCP(for: .npc)
}
```

**Validation Per Specialist:**
- Token reduction achieved
- Output quality maintained
- No new bugs introduced
- Metrics tracked

---

## Phase 6: Enable Quality Assurance (Week 4)

### Step 1: Add Narrative Intelligence Components

```swift
// In LLMGameEngine
private let analyzer = NarrativeAnalyzer()
private let validator = ConsistencyValidator()
private let stateLogger = StateLogger()
```

### Step 2: Add Validation Hooks

```swift
func advanceSceneSCP() async {
    // Pre-flight validation
    let preCheck = validator.validateBeforeLLMCall(...)
    guard preCheck.isValid else {
        logger.error("Pre-flight failed")
        return
    }
    
    // ... LLM call ...
    
    // Post-flight validation
    let postCheck = validator.validateAfterLLMResponse(...)
    if !postCheck.isValid {
        logger.error("Post-flight failed")
        // Could retry or apply corrections
    }
    
    // Log transition
    stateLogger.logTransition(...)
}
```

### Step 3: Start Quest Logging

```swift
func startNewAdventure() {
    // ...
    
    if FeatureFlags.shouldUseSCP(for: .adventure) {
        let questId = "q_\(UUID().uuidString.prefix(8))"
        stateLogger.startQuestLog(questId: questId)
        stateManager.startQuest(...)
    }
}

func completeAdventure() {
    // ...
    
    if FeatureFlags.shouldUseSCP(for: .adventure) {
        if let report = stateLogger.finalizeQuestLog() {
            metricsCollector.recordQuest(report)
            logger.info(report.summary)
        }
    }
}
```

**Validation:**
- Validation catches errors
- Logging works correctly
- Reports generated
- Metrics tracked

---

## Phase 7: Global Rollout (Week 5)

### Step 1: Enable All Specialists

```swift
// Enable globally
FeatureFlags.enableGlobalSCP()
```

### Step 2: Monitor Production

Track for 1 week:
- Consistency scores
- Token usage
- Generation times
- Error rates
- User feedback

### Step 3: Final Validation

```swift
// Run comprehensive test suite
xcodebuild test -scheme DunGen -destination 'platform=iOS,name=Momo'

// Check metrics
let metrics = metricsCollector.metrics
print(metrics.generateReport())

// Verify targets met
assert(metrics.averageConsistency > 0.70)
assert(metrics.averageTokenUsage < 300)
```

### Step 4: Remove Legacy Code (Optional)

Only after 2+ weeks of stable production:

```swift
// Remove legacy methods
func advanceSceneLegacy() async {
    // DELETE THIS METHOD
}

// Remove feature flag checks
func advanceScene() async {
    // Just call SCP directly
    await advanceSceneSCP()
}

// Remove FeatureFlags class
// DELETE: DunGen/Utilities/FeatureFlags.swift
```

**Validation:**
- System stable for 2+ weeks
- All metrics met targets
- No critical bugs
- Team approval obtained

---

## Rollback Procedures

### Immediate Rollback (Single Specialist)

```swift
// If issues detected with one specialist
FeatureFlags.disableSCP(for: .adventure)

// Game continues with legacy for that specialist
// Other specialists unaffected
```

### Full Rollback (All Specialists)

```swift
// If systemic issues detected
FeatureFlags.disableGlobalSCP()

// All specialists revert to legacy
// No code changes needed
```

### Rollback Checklist

- [ ] Identify affected specialist(s)
- [ ] Disable via feature flag
- [ ] Verify game functionality restored
- [ ] Document issue for investigation
- [ ] Fix issue in development
- [ ] Re-enable after validation

---

## Data Migration

### Game State Compatibility

**Good News:** Existing save files work with both systems!

```swift
// Legacy saves load correctly
func loadState() {
    // Existing code unchanged
    // If SCP enabled, create narrative state from loaded data
    if FeatureFlags.shouldUseSCP(for: .adventure) {
        stateManager.startQuest(...)
    }
}

// SCP saves include extra data
struct GameState: Codable {
    // ... existing fields ...
    
    // NEW: Optional narrative state (only if SCP used)
    var narrativeState: QuestNarrativeState?
}
```

### Save File Format

```json
{
  "character": { ... },
  "worldState": { ... },
  "adventureProgress": { ... },
  
  "narrativeState": {
    "questId": "q_abc123",
    "type": "retrieval",
    "threads": [...],
    "chain": [...],
    ...
  }
}
```

**Legacy Format (Pre-SCP):**
- `narrativeState` field missing or null
- Game loads and runs with legacy system

**SCP Format (Post-Migration):**
- `narrativeState` field present
- Game loads and runs with SCP system
- Can still fallback to legacy if needed

---

## Monitoring Dashboard

### Key Metrics to Track

```swift
struct MigrationMetrics {
    // Token usage
    var avgTokensLegacy: Int
    var avgTokensSCP: Int
    var tokenReduction: Double
    
    // Performance
    var avgTimeLegacy: TimeInterval
    var avgTimeSCP: TimeInterval
    
    // Quality
    var avgConsistency: Double
    var issueCount: Int
    var criticalIssues: Int
    
    // Adoption
    var percentSCPTurns: Double
    var percentLegacyTurns: Double
}
```

### Dashboard View

```swift
struct MigrationDashboardView: View {
    @State private var metrics: MigrationMetrics
    
    var body: some View {
        VStack {
            // Token reduction chart
            // Performance comparison
            // Quality scores
            // Adoption curve
        }
    }
}
```

---

## Testing During Migration

### A/B Testing

```swift
// Randomly assign specialists to SCP/legacy
func setupABTest() {
    let random = Bool.random()
    
    if random {
        FeatureFlags.enableSCP(for: .adventure)
    } else {
        // Use legacy
    }
    
    // Track which variant used
    analytics.track("variant", random ? "scp" : "legacy")
}

// Compare outcomes
func analyzeABTest() {
    let scpMetrics = getMetrics(variant: "scp")
    let legacyMetrics = getMetrics(variant: "legacy")
    
    // Statistical comparison
}
```

### Staged Rollout

```swift
// Week 1: 10% of players
if userId.hashValue % 10 == 0 {
    FeatureFlags.enableGlobalSCP()
}

// Week 2: 25% of players
if userId.hashValue % 4 == 0 {
    FeatureFlags.enableGlobalSCP()
}

// Week 3: 50% of players
if userId.hashValue % 2 == 0 {
    FeatureFlags.enableGlobalSCP()
}

// Week 4: 100% of players
FeatureFlags.enableGlobalSCP()
```

---

## Common Migration Issues

### Issue 1: Token Budget Exceeded

**Symptom:** Errors about context overflow

**Solution:**
```swift
// Reduce tier usage
let context = assembler.assembleContext(
    for: .adventure,
    maxTokens: budget.availableForState * 0.9  // Use 90% for safety
)
```

### Issue 2: Consistency Score Too Low

**Symptom:** Average consistency < 0.70

**Solution:**
```swift
// Review and tune analyzer weights
// Adjust tier priorities
// Add more context to narrative tier
```

### Issue 3: Performance Regression

**Symptom:** Generation time increased

**Solution:**
```swift
// Profile assembly time
// Optimize JSON serialization
// Cache assembled contexts
```

### Issue 4: Validation Errors

**Symptom:** Pre/post-flight validation failing

**Solution:**
```swift
// Review validation rules
// Adjust thresholds
// Add exception handling
```

---

## Success Criteria

Before declaring migration complete:

- [ ] All specialists migrated
- [ ] Token usage reduced 50%+ on average
- [ ] Consistency score > 0.70 average
- [ ] No critical bugs for 2 weeks
- [ ] Generation time ≤ legacy
- [ ] User satisfaction maintained
- [ ] Metrics tracked and validated
- [ ] Team approval obtained
- [ ] Documentation complete

---

## Post-Migration

### Cleanup Tasks

1. Remove feature flag system (optional)
2. Delete legacy methods
3. Update documentation
4. Archive migration logs
5. Share results with team

### Ongoing Monitoring

- Weekly metrics review
- Monthly quality audits
- Quarterly performance benchmarks
- Continuous improvement based on data

---

## Support

If issues during migration:

1. Check logs: `Documents/NarrativeLogs/`
2. Review metrics: `metricsCollector.generateReport()`
3. Inspect state: Use `NarrativeDebugView`
4. Rollback if needed: `FeatureFlags.disableGlobalSCP()`
5. Document and investigate offline

**Remember:** Easy rollback means low risk!
