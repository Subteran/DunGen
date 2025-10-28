# DunGen Narrative Improvement Implementation Plan

**Goal:** Improve narrative consistency, structure, and quality through 4 focused features
**Timeline:** 4-6 weeks (one feature per 1-2 weeks)
**Approach:** Incremental implementation with testing between phases

---

## Overview

### Features (In Order)
1. **Consistency Contract (CC)** - Prevent time/weather/location/POV drift
2. **Beat Templates** - Improve narrative structure and variety
3. **Narrative Linter** - Deterministic quality improvements
4. **Open Threads** - Track and resolve narrative promises

### Success Metrics
- **Consistency:** <1% turns with drift violations
- **Structure:** >80% turns follow beat templates
- **Quality:** Zero raw stats in narrative, consistent POV/tense
- **Threads:** >80% threads resolved within due window

---

## Phase 1: Consistency Contract (CC)
**Duration:** 1 week
**Goal:** Eliminate time/weather/location/POV drift

### 1.1 Analysis & Design (Day 1)

**Define CC Schema:**
```swift
struct ConsistencyContract {
    var pov: String          // "2P" (second person)
    var tense: String        // "Pres" (present)
    var location: String     // Current location name
    var questGoal: String    // Active quest (abbreviated)
    var questStage: String   // "EARLY" / "MID" / "FINAL"
    var timeOfDay: String?   // "dawn" / "midday" / "dusk" / "night" (optional)
    var weather: String?     // "clear" / "rain" / "fog" / "storm" (optional)

    func toCompactString() -> String {
        var parts = [
            "POV=\(pov)",
            "Tense=\(tense)",
            "Loc=\(location)",
            "Q=\(questGoal.prefix(20))",
            "Stage=\(questStage)"
        ]
        if let time = timeOfDay {
            parts.append("Time=\(time)")
        }
        if let wx = weather {
            parts.append("Wx=\(wx)")
        }
        return "CC: " + parts.joined(separator: " ")
    }
}
```

**Example Output:**
```
CC: POV=2P Tense=Pres Loc=Thornhaven Q=RetrieveAmulet Stage=MID Time=dusk Wx=fog
```

**Estimated Size:** 80-120 characters

---

### 1.2 Implementation (Days 2-3)

**Files to Modify:**
1. `LLMGameEngine.swift` - Add CC property and initialization
2. `ContextBuilder.swift` - Add CC to all specialist contexts
3. `adventure.txt` - Add CC enforcement rule
4. `GameStatePersistence.swift` - Persist CC in save state

**Step 1: Add CC to LLMGameEngine**
```swift
// LLMGameEngine.swift
var consistencyContract: ConsistencyContract?

// Initialize CC when adventure starts
private func initializeConsistencyContract(location: String, questGoal: String) {
    consistencyContract = ConsistencyContract(
        pov: "2P",
        tense: "Pres",
        location: location,
        questGoal: questGoal,
        questStage: "EARLY",
        timeOfDay: nil,  // Let LLM establish
        weather: nil     // Let LLM establish
    )
}

// Update CC when quest stage changes
private func updateConsistencyContract(questStage: String) {
    consistencyContract?.questStage = questStage
}
```

**Step 2: Inject CC into ContextBuilder**
```swift
// ContextBuilder.swift - buildAdventureContext()
static func buildAdventureContext(
    // ... existing parameters
    consistencyContract: ConsistencyContract?
) -> String {
    var lines: [String] = []

    // CC ALWAYS FIRST (Tier 1 priority)
    if let cc = consistencyContract {
        lines.append(cc.toCompactString())
    }

    // ... rest of context
}
```

**Step 3: Update adventure.txt**
```
CRITICAL: Honor CC (Consistency Contract) in all output.
- POV: Use exact POV shown (2P = "you see", "you walk")
- Tense: Use exact tense shown (Pres = present tense only)
- Loc: Scene must occur at location shown
- Time/Wx: If shown, maintain throughout turn (no "noon" if Time=dusk)
```

**Step 4: Update smart truncation to preserve CC**
```swift
// NarrativeProcessor.swift - smartTruncatePrompt()
let mustKeep = lineLower.contains("cc:") ||  // HIGHEST priority
              lineLower.contains("⚠") ||
              lineLower.contains("stage-") ||
              // ... rest
```

**Step 5: Persist CC in save state**
```swift
// GameStatePersistence.swift
struct GameState: Codable {
    // ... existing fields
    var consistencyContract: ConsistencyContract?
}
```

---

### 1.3 Testing (Day 4)

**Manual Test Cases:**
1. Start new adventure → verify CC initialized with location + quest
2. Play 3 turns → check narrative uses "you" (not "he/she/the hero")
3. Play 3 turns → check narrative uses present tense (not past)
4. Check if LLM establishes time/weather → verify maintained across turns
5. Advance to MID stage → verify CC.questStage updates
6. Save/load game → verify CC persists
7. Complete quest, start new location → verify CC updates to new location

**Automated Test:**
```swift
@Test("CC maintains location across turns")
func testCCLocationConsistency() async throws {
    let engine = MockGameEngine(mode: .llm)
    await setupGameWithAdventure(engine, preferredType: .village)

    let initialLocation = engine.consistencyContract?.location

    // Take 3 turns
    for _ in 0..<3 {
        await engine.submitPlayer(input: "explore the area")
        #expect(engine.consistencyContract?.location == initialLocation)
    }
}
```

**Acceptance Criteria:**
- ✅ CC appears in all Adventure LLM prompts
- ✅ CC preserved during smart truncation
- ✅ CC persists across save/load
- ✅ CC updates when quest stage changes
- ✅ No time/weather drift observed in 10-turn test

---

### 1.4 Refinement (Day 5)

**Extract time/weather from LLM output (optional enhancement):**
```swift
// Parse first narrative turn to establish time/weather if not set
private func extractTimeWeatherFromNarrative(_ narrative: String) {
    guard consistencyContract?.timeOfDay == nil else { return }

    let timeKeywords = ["dawn": "dawn", "morning": "dawn",
                        "noon": "midday", "afternoon": "midday",
                        "dusk": "dusk", "evening": "dusk", "twilight": "dusk",
                        "night": "night", "midnight": "night"]

    let weatherKeywords = ["rain": "rain", "storm": "storm", "fog": "fog",
                          "clear": "clear", "sunny": "clear", "cloud": "cloud"]

    let lower = narrative.lowercased()
    for (keyword, value) in timeKeywords {
        if lower.contains(keyword) {
            consistencyContract?.timeOfDay = value
            break
        }
    }

    for (keyword, value) in weatherKeywords {
        if lower.contains(keyword) {
            consistencyContract?.weather = value
            break
        }
    }
}
```

**Logging for drift detection:**
```swift
// After Adventure LLM call
let narrative = turn.narration.lowercased()
if let cc = consistencyContract {
    if narrative.contains("he ") || narrative.contains("she ") {
        logger.warning("[CC Violation] POV drift detected: third person in narrative")
    }
    if let time = cc.timeOfDay, !narrative.contains(time) {
        // Check for conflicting time words
        let conflictingTimes = ["dawn", "noon", "dusk", "night"].filter {
            $0 != time && narrative.contains($0)
        }
        if !conflictingTimes.isEmpty {
            logger.warning("[CC Violation] Time drift: expected \(time), found \(conflictingTimes)")
        }
    }
}
```

---

### 1.5 Documentation (Day 5)

Update `CLAUDE.md`:
```markdown
### Consistency Contract (CC)

**Purpose:** Prevent narrative drift in POV, tense, time, weather, and location.

**Schema:**
- `POV=2P` - Always second person ("you see", not "he sees")
- `Tense=Pres` - Always present tense ("you walk", not "you walked")
- `Loc=<location>` - Current location (must match scene)
- `Q=<questGoal>` - Active quest (abbreviated to 20 chars)
- `Stage=EARLY|MID|FINAL` - Quest progression stage
- `Time=dawn|midday|dusk|night` - Time of day (optional, extracted from first turn)
- `Wx=clear|rain|fog|storm|cloud` - Weather (optional, extracted from first turn)

**Enforcement:**
- CC injected at top of all Adventure LLM prompts
- Preserved during smart truncation (highest priority)
- Updated when quest stage changes
- Persisted in save state
- Logging detects POV/time drift violations
```

Update `LLM_SYSTEM.md` Section 3 (Adventure Specialist):
```markdown
**Context Provided (Compressed):**
```
CC: POV=2P Tense=Pres Loc=Thornhaven Q=RetrieveAmulet Stage=MID Time=dusk Wx=fog
Char: Kael L5 Warrior HP:45 G:120
Enc: exploration (normal)
Monster: Ancient Goblin (HP: 28, Damage: 6)
```
```

---

## Phase 2: Beat Templates
**Duration:** 1 week
**Goal:** Structure narrative turns with clear story beats

### 2.1 Analysis & Design (Day 1)

**Define Beat Templates:**

**Exploration Beat:**
```
1. Setting (1 sentence) - Where you are, what you notice
2. Discovery/Texture (1 sentence) - What you find or observe
3. Hook/Complication (1 sentence) - What happens next, tension
[Optional: Internal beat - character reaction]
```

**Social Beat:**
```
1. Setting (1 sentence) - NPC appearance, context
2. Motive Reveal (1 sentence) - What NPC wants/offers
3. Tension (1 sentence) - Stakes, conflict, or choice
[Optional: Exit beat - conversation conclusion]
```

**Trap Beat:**
```
1. Discovery (1 sentence) - Trap revealed
2. Danger (1 sentence) - Immediate threat
3. Options (referenced in suggestedActions, NOT narrative)
```

**Final Encounter Beat (Non-Combat):**
```
1. Arrival (1 sentence) - Quest objective present
2. Achievement (1 sentence) - How to complete
3. Resolution (1 sentence) - Success implications
```

**Requirements:**
- Total: 2-4 sentences, ≤85 words
- ≥1 sensory detail per turn
- ≤1 new proper noun per turn
- No item grants in narrative

---

### 2.2 Implementation (Days 2-3)

**Step 1: Add beat templates to adventure.txt**
```
STRUCTURE (2-4 sentences, ≤85 words):
Exploration: Setting→Discovery→Hook (±1 sensory detail)
Social: Setting→Motive→Tension (NPC appearance→want→stakes)
Trap: Discovery→Danger (options in suggestedActions only)
Final: Arrival→Achievement→Resolution

RULES:
• ≥1 sensory detail (sight/sound/smell/touch)
• ≤1 new proper noun per turn
• NO item grants in narrative (use suggestedActions)
```

**Step 2: Create beat template validator (deterministic)**
```swift
// NarrativeProcessor.swift
struct BeatTemplateValidator {
    func validate(narrative: String, encounterType: String) -> BeatValidationResult {
        let sentences = narrative.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let wordCount = narrative.split(separator: " ").count

        var issues: [String] = []

        // Check sentence count
        if sentences.count < 2 || sentences.count > 4 {
            issues.append("Expected 2-4 sentences, got \(sentences.count)")
        }

        // Check word count
        if wordCount > 85 {
            issues.append("Exceeded 85 words (got \(wordCount))")
        }

        // Check for sensory details
        let sensoryWords = ["see", "hear", "smell", "feel", "touch", "taste",
                           "glow", "shimmer", "creak", "whisper", "reek", "stench",
                           "warm", "cold", "rough", "smooth", "sweet", "bitter"]
        let hasSensory = sensoryWords.contains { narrative.lowercased().contains($0) }
        if !hasSensory {
            issues.append("Missing sensory detail")
        }

        // Check for excessive proper nouns (capitalized words not at sentence start)
        let properNouns = narrative.matches(of: /\s([A-Z][a-z]+)/)
            .map { String($0.output.1) }
        if properNouns.count > 1 {
            issues.append("Too many proper nouns (\(properNouns.count)): \(properNouns.joined(separator: ", "))")
        }

        return BeatValidationResult(
            valid: issues.isEmpty,
            issues: issues,
            sentenceCount: sentences.count,
            wordCount: wordCount
        )
    }
}

struct BeatValidationResult {
    let valid: Bool
    let issues: [String]
    let sentenceCount: Int
    let wordCount: Int
}
```

**Step 3: Log validation results**
```swift
// LLMGameEngine.swift - after Adventure LLM call
let validator = BeatTemplateValidator()
let validation = validator.validate(narrative: turn.narration, encounterType: encounter.encounterType)
if !validation.valid {
    logger.warning("[Beat Template] Validation failed: \(validation.issues.joined(separator: ", "))")
} else {
    logger.debug("[Beat Template] Valid: \(validation.sentenceCount) sentences, \(validation.wordCount) words")
}
```

---

### 2.3 Testing (Day 4)

**Manual Test Cases:**
1. **Exploration turn** → verify: setting sentence + discovery sentence + hook sentence
2. **Social turn** → verify: NPC appearance + motive + tension
3. **Trap turn** → verify: discovery + danger (no options in narrative)
4. **Final turn** → verify: arrival + achievement + resolution
5. Check for sensory details in all turns
6. Check no more than 1 new proper noun per turn
7. Verify 2-4 sentences, ≤85 words

**Automated Test:**
```swift
@Test("Beat template validator detects structure violations")
func testBeatTemplateValidation() {
    let validator = BeatTemplateValidator()

    // Too short
    let tooShort = "You enter the room."
    let result1 = validator.validate(narrative: tooShort, encounterType: "exploration")
    #expect(!result1.valid)
    #expect(result1.issues.contains { $0.contains("2-4 sentences") })

    // Too long (word count)
    let tooLong = String(repeating: "You walk through the forest and see many trees and birds and animals and flowers and streams. ", count: 3)
    let result2 = validator.validate(narrative: tooLong, encounterType: "exploration")
    #expect(!result2.valid)
    #expect(result2.issues.contains { $0.contains("85 words") })

    // Missing sensory
    let noSensory = "You arrive. A merchant appears. He offers goods."
    let result3 = validator.validate(narrative: noSensory, encounterType: "social")
    #expect(!result3.valid)
    #expect(result3.issues.contains { $0.contains("sensory") })

    // Valid
    let valid = "You step into the misty clearing. A weathered shrine stands before you. Strange symbols glow faintly on its surface."
    let result4 = validator.validate(narrative: valid, encounterType: "exploration")
    #expect(result4.valid)
}
```

**Acceptance Criteria:**
- ✅ Beat templates added to adventure.txt
- ✅ Validator detects sentence count violations
- ✅ Validator detects word count violations
- ✅ Validator detects missing sensory details
- ✅ Validator detects excessive proper nouns
- ✅ Validation logging shows quality metrics

---

### 2.4 Refinement (Day 5)

**Add sensory rotation hint (optional):**
```swift
// Track last sensory type used
var lastSensoryType: String? = nil  // "sight", "sound", "smell", "touch"

// Before Adventure LLM call
let sensoryHint = getSensoryHint()

// In ContextBuilder
func getSensoryHint() -> String {
    let rotation = ["sight", "sound", "smell", "touch"]
    guard let last = lastSensoryType,
          let index = rotation.firstIndex(of: last) else {
        return "Use sight details"
    }
    let next = rotation[(index + 1) % rotation.count]
    return "Use \(next) details"
}
```

Add to adventure.txt:
```
SENSORY: Vary details - sight→sound→smell→touch rotation preferred
```

**Add encounter-specific beat examples:**
```
EXAMPLES:
Exploration: "The tunnel narrows ahead. Water drips from stalactites above. A faint light glimmers in the distance."
Social: "An elderly woman tends a market stall. She eyes you warily, clutching a weathered ledger. 'Looking for something rare?' she asks."
Trap: "Pressure plates line the corridor floor. One wrong step could trigger the blade mechanisms visible in the walls."
```

---

### 2.5 Documentation (Day 5)

Update `CLAUDE.md`:
```markdown
### Beat Templates

**Purpose:** Structure narrative turns for variety and quality.

**Templates:**
- **Exploration:** Setting → Discovery → Hook (±sensory)
- **Social:** Setting → Motive → Tension
- **Trap:** Discovery → Danger (options in suggestedActions)
- **Final:** Arrival → Achievement → Resolution

**Validation:**
- Deterministic validator checks structure
- Logs violations: sentence count, word count, sensory details, proper noun count
- Does not block output (logging only)

**Requirements:**
- 2-4 sentences
- ≤85 words
- ≥1 sensory detail
- ≤1 new proper noun
```

---

## Phase 3: Narrative Linter
**Duration:** 1 week
**Goal:** Deterministic post-processing for quality improvements

### 3.1 Analysis & Design (Day 1)

**Linter Rules (Priority Order):**

1. **POV Enforcement** - Convert third person to second person
2. **Number Replacement** - Replace raw stats with diegetic descriptions
3. **Acquisition Verb Detection** - Move item grants to suggestedActions
4. **Proper Noun Throttling** - Downcase excessive proper nouns

**Examples:**

**Rule 1: POV Enforcement**
```
Before: "The hero sees a goblin. He draws his sword."
After:  "You see a goblin. You draw your sword."
```

**Rule 2: Number Replacement**
```
Before: "You have 45 HP. You found 20 gold."
After:  "Your wounds ache but you stand firm. You found a pouch of coins."
```

**Rule 3: Acquisition Verb Detection**
```
Before: "You pick up the amulet and gain 50 gold."
After:  "The amulet lies before you." (add "Take the amulet" to suggestedActions)
```

**Rule 4: Proper Noun Throttling**
```
Before: "Eldara the Merchant offers wares. Garrick the Blacksmith watches. Theron the Guard approaches."
After:  "Eldara the Merchant offers wares. A blacksmith watches. A guard approaches."
```

---

### 3.2 Implementation (Days 2-4)

**Create NarrativeLinter class:**

```swift
// NarrativeProcessor.swift
final class NarrativeLinter {

    // RULE 1: POV Enforcement (third person → second person)
    func enforcePOV(_ text: String) -> String {
        var result = text

        // Replace common third-person patterns
        let replacements: [(String, String)] = [
            ("The hero ", "You "),
            ("the hero ", "you "),
            (" he ", " you "),
            (" He ", " You "),
            (" his ", " your "),
            (" His ", " Your "),
            (" him ", " you "),
            (" Him ", " You "),
            (" she ", " you "),
            (" She ", " You "),
            (" her ", " your "),
            (" Her ", " Your ")
        ]

        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(of: pattern, with: replacement)
        }

        return result
    }

    // RULE 2: Number Replacement (stats → diegetic)
    func replaceDiegeticNumbers(_ text: String, currentHP: Int, maxHP: Int) -> String {
        var result = text

        // HP mentions
        let hpPattern = /\b(\d+)\s*HP\b/
        result = result.replacing(hpPattern) { match in
            let value = Int(match.output.1) ?? 0
            return hpToDiegetic(value, max: maxHP)
        }

        // Gold mentions
        let goldPattern = /\b(\d+)\s*gold\b/
        result = result.replacing(goldPattern) { match in
            let value = Int(match.output.1) ?? 0
            return goldToDiegetic(value)
        }

        // XP mentions
        let xpPattern = /\b(\d+)\s*XP\b/
        result = result.replacing(xpPattern) { _ in
            "valuable experience"
        }

        return result
    }

    private func hpToDiegetic(_ value: Int, max: Int) -> String {
        let ratio = Double(value) / Double(max)
        if ratio > 0.8 { return "strong and ready" }
        if ratio > 0.5 { return "wounds aching but standing firm" }
        if ratio > 0.2 { return "badly wounded" }
        return "barely standing"
    }

    private func goldToDiegetic(_ value: Int) -> String {
        if value > 100 { return "a substantial fortune" }
        if value > 50 { return "a heavy pouch of coins" }
        if value > 10 { return "a pouch of coins" }
        return "a few coins"
    }

    // RULE 3: Acquisition Verb Detection
    func detectAcquisitions(_ text: String) -> (cleanedText: String, suggestedActions: [String]) {
        var suggestions: [String] = []
        var result = text

        // Patterns that suggest item acquisition
        let acquisitionPatterns: [(pattern: Regex<AnyRegexOutput>, template: String)] = [
            (/you pick up the (\w+)/, "Take the $1"),
            (/you take the (\w+)/, "Take the $1"),
            (/you grab the (\w+)/, "Take the $1"),
            (/you find (?:a |an |the )?(\w+)/, "Take the $1"),
            (/you gain (\d+) gold/, "Collect the gold"),
            (/you receive (?:a |an |the )?(\w+)/, "Accept the $1")
        ]

        for (pattern, template) in acquisitionPatterns {
            if let match = result.firstMatch(of: pattern) {
                // Extract item name
                let itemName = String(match.output.1 as? Substring ?? "item")
                suggestions.append(template.replacingOccurrences(of: "$1", with: itemName))

                // Remove the acquisition sentence
                result = result.replacing(pattern, with: "")
            }
        }

        return (result.trimmingCharacters(in: .whitespacesAndNewlines), suggestions)
    }

    // RULE 4: Proper Noun Throttling
    func throttleProperNouns(_ text: String, maxAllowed: Int = 1) -> String {
        // Find all capitalized words that aren't sentence-starting
        let pattern = /\s([A-Z][a-z]+)/
        let matches = text.matches(of: pattern)

        guard matches.count > maxAllowed else { return text }

        var result = text
        var count = 0

        // Keep first N, downcase the rest
        for match in matches {
            count += 1
            if count > maxAllowed {
                let properNoun = String(match.output.1)
                // Convert to generic equivalent
                let generic = properNounToGeneric(properNoun)
                result = result.replacingOccurrences(of: " \(properNoun)", with: " \(generic)")
            }
        }

        return result
    }

    private func properNounToGeneric(_ noun: String) -> String {
        let lower = noun.lowercased()

        // Common NPC occupations
        if ["merchant", "trader", "vendor"].contains(where: { lower.contains($0) }) {
            return "a merchant"
        }
        if ["guard", "soldier", "warrior"].contains(where: { lower.contains($0) }) {
            return "a guard"
        }
        if ["blacksmith", "smith"].contains(where: { lower.contains($0) }) {
            return "a blacksmith"
        }
        if ["priest", "cleric", "healer"].contains(where: { lower.contains($0) }) {
            return "a priest"
        }

        // Default: article + lowercase
        return "a \(lower)"
    }

    // Master linting function
    func lint(_ text: String, currentHP: Int, maxHP: Int, consistencyContract: ConsistencyContract?) -> LintResult {
        var result = text
        var actions: [String] = []

        // Apply rules in order
        result = enforcePOV(result)
        result = replaceDiegeticNumbers(result, currentHP: currentHP, maxHP: maxHP)

        let (cleaned, suggestedActions) = detectAcquisitions(result)
        result = cleaned
        actions = suggestedActions

        result = throttleProperNouns(result, maxAllowed: 1)

        return LintResult(
            lintedText: result,
            suggestedActions: actions,
            rulesApplied: ["POV", "Numbers", "Acquisitions", "ProperNouns"]
        )
    }
}

struct LintResult {
    let lintedText: String
    let suggestedActions: [String]
    let rulesApplied: [String]
}
```

**Integrate into sanitization pipeline:**
```swift
// NarrativeProcessor.swift - update sanitizeNarration
func sanitizeNarration(_ text: String, for encounterType: String?, expectedMonster: MonsterDefinition? = nil, currentHP: Int = 0, maxHP: Int = 0, consistencyContract: ConsistencyContract? = nil) -> (narrative: String, suggestedActions: [String]) {

    // STEP 1: Lint (deterministic quality improvements)
    let linter = NarrativeLinter()
    let lintResult = linter.lint(text, currentHP: currentHP, maxHP: maxHP, consistencyContract: consistencyContract)
    var sanitized = lintResult.lintedText

    // STEP 2: Combat verb sanitization (existing)
    let forbidden = ["defeat", "defeated", "kill", "killed", "slay", "slain", "strike", "struck", "smite", "smitten", "crush", "crushed", "stab", "stabbed", "shoot", "shot", "damage", "wound", "wounded"]
    if let type = encounterType, type == "combat" || type == "final" {
        for word in forbidden {
            sanitized = sanitized.replacingOccurrences(of: word, with: "confront", options: [.caseInsensitive, .regularExpression])
        }
    }

    // STEP 3: Action suggestion removal (existing)
    sanitized = removeActionSuggestions(from: sanitized)

    // STEP 4: Monster validation (existing)
    sanitized = validateMonsterReferences(in: sanitized, expectedMonster: expectedMonster)

    return (sanitized, lintResult.suggestedActions)
}
```

**Update call sites:**
```swift
// LLMGameEngine.swift
let (cleanedNarration, lintedActions) = sanitizeNarration(
    turn.narration,
    for: encounter?.encounterType,
    expectedMonster: monster,
    currentHP: character?.hp ?? 0,
    maxHP: character?.maxHP ?? 0,
    consistencyContract: consistencyContract
)

// Merge linted actions with LLM suggestions
var finalActions = turn.suggestedActions
finalActions.append(contentsOf: lintedActions)
updateSuggestedActions(Array(finalActions.prefix(4)))  // Max 4 actions

appendModel(cleanedNarration)
```

---

### 3.3 Testing (Days 4-5)

**Unit Tests:**
```swift
@Test("Linter enforces POV")
func testLinterPOV() {
    let linter = NarrativeLinter()
    let input = "The hero sees a goblin. He draws his sword."
    let output = linter.enforcePOV(input)
    #expect(output == "You see a goblin. You draw your sword.")
}

@Test("Linter replaces HP numbers")
func testLinterHPReplacement() {
    let linter = NarrativeLinter()
    let input = "You have 45 HP remaining."
    let output = linter.replaceDiegeticNumbers(input, currentHP: 45, maxHP: 50)
    #expect(output.contains("strong and ready") || output.contains("wounds aching"))
    #expect(!output.contains("45 HP"))
}

@Test("Linter detects acquisitions")
func testLinterAcquisitions() {
    let linter = NarrativeLinter()
    let input = "You find a golden amulet. You pick up the key."
    let (cleaned, actions) = linter.detectAcquisitions(input)
    #expect(actions.count == 2)
    #expect(actions.contains("Take the amulet"))
    #expect(actions.contains("Take the key"))
    #expect(!cleaned.contains("pick up"))
}

@Test("Linter throttles proper nouns")
func testLinterProperNouns() {
    let linter = NarrativeLinter()
    let input = "Eldara the Merchant offers wares. Garrick the Blacksmith watches. Theron the Guard approaches."
    let output = linter.throttleProperNouns(input, maxAllowed: 1)
    #expect(output.contains("Eldara"))
    #expect(!output.contains("Garrick"))
    #expect(!output.contains("Theron"))
    #expect(output.contains("a blacksmith") || output.contains("a guard"))
}

@Test("Full linting pipeline")
func testFullLinting() {
    let linter = NarrativeLinter()
    let input = "The hero has 30 HP. He picks up the sword and gains 10 gold. Merchant Bob and Guard Tom appear."
    let result = linter.lint(input, currentHP: 30, maxHP: 50, consistencyContract: nil)

    #expect(!result.lintedText.contains("The hero"))
    #expect(!result.lintedText.contains(" he "))
    #expect(!result.lintedText.contains("30 HP"))
    #expect(!result.lintedText.contains("10 gold"))
    #expect(!result.lintedText.contains("picks up"))
    #expect(result.suggestedActions.contains { $0.contains("sword") })
}
```

**Manual Test Cases:**
1. Generate narrative with "The hero" → verify converted to "You"
2. Generate narrative with "45 HP" → verify replaced with diegetic text
3. Generate narrative with "you pick up the amulet" → verify moved to actions
4. Generate narrative with 3 proper nouns → verify only 1 preserved
5. Check that linting doesn't break valid narrative

**Acceptance Criteria:**
- ✅ POV enforcement converts third person to second person
- ✅ Number replacement converts stats to diegetic descriptions
- ✅ Acquisition detection moves grants to suggestedActions
- ✅ Proper noun throttling limits to 1 per turn
- ✅ Linting preserves narrative meaning
- ✅ All unit tests pass

---

### 3.4 Refinement (Day 5)

**Add tense enforcement (optional, if time permits):**
```swift
// Simple past tense → present tense conversion
func enforceTense(_ text: String) -> String {
    var result = text

    // Simple past → present (regular verbs)
    let regularPatterns: [(String, String)] = [
        ("walked", "walk"),
        ("talked", "talk"),
        ("looked", "look"),
        ("opened", "open"),
        ("closed", "close"),
        ("entered", "enter"),
        ("discovered", "discover")
    ]

    for (past, present) in regularPatterns {
        result = result.replacingOccurrences(of: past, with: present, options: .caseInsensitive)
    }

    // Irregular verbs (limited set)
    let irregularPatterns: [(String, String)] = [
        ("saw", "see"),
        ("went", "go"),
        ("came", "come"),
        ("took", "take"),
        ("gave", "give"),
        ("found", "find"),
        ("stood", "stand")
    ]

    for (past, present) in irregularPatterns {
        result = result.replacingOccurrences(of: " \(past) ", with: " \(present) ", options: .caseInsensitive)
    }

    return result
}
```

⚠️ **Warning:** Tense conversion is hard and error-prone. Only implement if testing shows it works reliably.

---

### 3.5 Documentation (Day 5)

Update `CLAUDE.md`:
```markdown
### Narrative Linter

**Purpose:** Deterministic post-processing for quality improvements.

**Rules Applied (In Order):**
1. **POV Enforcement** - Third person → second person
2. **Number Replacement** - Stats → diegetic descriptions
3. **Acquisition Detection** - Item grants → suggestedActions
4. **Proper Noun Throttling** - Limit to 1 per turn

**Examples:**
- "The hero sees a goblin" → "You see a goblin"
- "You have 45 HP" → "Your wounds ache but you stand firm"
- "You pick up the sword" → "The sword lies before you" + action "Take the sword"
- "Eldara, Garrick, and Theron appear" → "Eldara, a blacksmith, and a guard appear"

**Integration:**
- Runs before existing sanitization (combat verbs, action suggestions, monster validation)
- Returns both cleaned narrative and extracted suggestedActions
- Preserves narrative meaning while improving quality
```

---

## Phase 4: Open Threads
**Duration:** 2 weeks
**Goal:** Track narrative promises and ensure resolution

### 4.1 Analysis & Design (Days 1-2)

**Define Thread System:**

```swift
struct OpenThread: Codable, Identifiable {
    var id: String              // "T1", "T2", etc.
    var description: String     // "crow totem mystery"
    var introducedAt: Int       // Encounter number when created
    var dueBy: Int             // introducedAt + windowSize
    var resolved: Bool
    var resolvedAt: Int?
    var windowSize: Int        // 3 encounters default

    var turnsRemaining: Int {
        return max(0, dueBy - (introducedAt + (resolvedAt ?? 0)))
    }

    var isOverdue: Bool {
        guard !resolved else { return false }
        return turnsRemaining <= 0
    }
}

struct ThreadManager {
    private(set) var threads: [OpenThread] = []
    private var nextID: Int = 1

    mutating func createThread(description: String, currentEncounter: Int, windowSize: Int = 3) -> OpenThread {
        let thread = OpenThread(
            id: "T\(nextID)",
            description: description,
            introducedAt: currentEncounter,
            dueBy: currentEncounter + windowSize,
            resolved: false,
            windowSize: windowSize
        )
        nextID += 1
        threads.append(thread)
        return thread
    }

    mutating func resolveThread(id: String, atEncounter: Int) {
        if let index = threads.firstIndex(where: { $0.id == id }) {
            threads[index].resolved = true
            threads[index].resolvedAt = atEncounter
        }
    }

    func activeThreads(currentEncounter: Int) -> [OpenThread] {
        return threads.filter { !$0.resolved && !$0.isOverdue }
            .sorted { $0.turnsRemaining < $1.turnsRemaining }
    }

    func overdueThreads() -> [OpenThread] {
        return threads.filter { $0.isOverdue && !$0.resolved }
    }

    mutating func cleanupResolvedThreads() {
        threads.removeAll { $0.resolved }
    }
}
```

**Thread Creation Strategy:**

**Automatic Detection (Heuristic):**
- NPCs with promises → auto-create thread
- Items mentioned but not acquired → potential thread
- Locations mentioned but not visited → potential thread

**Manual Extraction (LLM Output):**
Extend `AdventureTurn` schema:
```swift
struct AdventureTurn: Codable {
    // ... existing fields
    var newThreads: [String]?      // ["crow totem mystery", "rumor about old well"]
    var resolvedThreads: [String]? // ["T2", "T5"]
}
```

**Context Injection:**
```
Active Threads: T12 "crow totem" (due in 2), T7 "old well rumor" (due in 1)
```

---

### 4.2 Implementation (Days 3-7)

**Step 1: Add ThreadManager to LLMGameEngine**
```swift
// LLMGameEngine.swift
var threadManager = ThreadManager()

// After adventure LLM call
func processThreads(turn: AdventureTurn, currentEncounter: Int) {
    // Create new threads from LLM output
    if let newThreads = turn.newThreads {
        for description in newThreads {
            let thread = threadManager.createThread(
                description: description,
                currentEncounter: currentEncounter,
                windowSize: 3
            )
            logger.debug("[Threads] Created: \(thread.id) '\(thread.description)' (due in \(thread.windowSize))")
        }
    }

    // Resolve threads from LLM output
    if let resolvedIDs = turn.resolvedThreads {
        for id in resolvedIDs {
            threadManager.resolveThread(id: id, atEncounter: currentEncounter)
            logger.info("[Threads] Resolved: \(id)")
        }
    }

    // Auto-detect resolution from narrative
    autoDetectResolution(narrative: turn.narration, currentEncounter: currentEncounter)

    // Log overdue threads
    let overdue = threadManager.overdueThreads()
    if !overdue.isEmpty {
        logger.warning("[Threads] Overdue: \(overdue.map { "\($0.id) '\($0.description)'" }.joined(separator: ", "))")
    }
}

private func autoDetectResolution(narrative: String, currentEncounter: Int) {
    let active = threadManager.activeThreads(currentEncounter: currentEncounter)
    let lower = narrative.lowercased()

    for thread in active {
        // Check if thread description keywords appear in narrative
        let keywords = thread.description.lowercased().split(separator: " ")
        let mentionCount = keywords.filter { lower.contains($0) }.count

        // If >50% of keywords mentioned, consider resolved
        if Double(mentionCount) / Double(keywords.count) > 0.5 {
            threadManager.resolveThread(id: thread.id, atEncounter: currentEncounter)
            logger.info("[Threads] Auto-resolved: \(thread.id) '\(thread.description)' (keywords matched in narrative)")
        }
    }
}
```

**Step 2: Inject threads into ContextBuilder**
```swift
// ContextBuilder.swift
static func buildAdventureContext(
    // ... existing parameters
    threadManager: ThreadManager?,
    currentEncounter: Int
) -> String {
    var lines: [String] = []

    // CC first
    if let cc = consistencyContract {
        lines.append(cc.toCompactString())
    }

    // ... other context

    // Active threads (max 2 for context budget)
    if let manager = threadManager {
        let active = manager.activeThreads(currentEncounter: currentEncounter).prefix(2)
        if !active.isEmpty {
            let threadSummary = active.map {
                "\($0.id) '\($0.description)' (due in \($0.turnsRemaining))"
            }.joined(separator: ", ")
            lines.append("Threads: \(threadSummary)")
        }
    }

    return lines.joined(separator: "\n")
}
```

**Step 3: Update adventure.txt**
```
THREADS (optional narrative promises):
If "Threads:" present, reference ≥1 thread ID in output.
Mark resolved via resolvedThreads field when promise fulfilled.
Create new threads via newThreads field for new mysteries/promises.

EXAMPLES:
- Thread T12 "crow totem": mention finding or learning about it
- Resolution: set resolvedThreads=["T12"] when mystery solved
```

**Step 4: Update AdventureTurn schema**
```swift
struct AdventureTurn: Codable {
    var narration: String
    var adventureProgress: AdventureProgress?
    var suggestedActions: [String]
    var currentEnvironment: String?
    var itemsAcquired: [String]?
    var goldSpent: Int?
    var playerPrompt: String?

    // NEW: Thread tracking
    var newThreads: [String]?      // Threads introduced this turn
    var resolvedThreads: [String]? // Thread IDs resolved this turn
}
```

**Step 5: Persist threads**
```swift
// GameStatePersistence.swift
struct GameState: Codable {
    // ... existing fields
    var threadManager: ThreadManager?
}
```

**Step 6: Add thread UI visualization (optional)**
```swift
// GameView.swift - add to debug toolbar or settings
if let manager = engine.threadManager {
    VStack(alignment: .leading) {
        Text("Open Threads:").font(.headline)
        ForEach(manager.activeThreads(currentEncounter: engine.adventureProgress?.currentEncounter ?? 0)) { thread in
            HStack {
                Text("\(thread.id):")
                Text(thread.description)
                Spacer()
                Text("(\(thread.turnsRemaining) left)")
                    .foregroundColor(thread.turnsRemaining <= 1 ? .red : .orange)
            }
        }
    }
}
```

---

### 4.3 Testing (Days 8-10)

**Unit Tests:**
```swift
@Test("Thread creation and tracking")
func testThreadCreation() {
    var manager = ThreadManager()

    let thread1 = manager.createThread(description: "crow totem mystery", currentEncounter: 1, windowSize: 3)
    #expect(thread1.id == "T1")
    #expect(thread1.dueBy == 4)
    #expect(!thread1.resolved)

    let active = manager.activeThreads(currentEncounter: 1)
    #expect(active.count == 1)
    #expect(active[0].turnsRemaining == 3)
}

@Test("Thread resolution")
func testThreadResolution() {
    var manager = ThreadManager()

    let thread = manager.createThread(description: "old well rumor", currentEncounter: 1, windowSize: 3)
    manager.resolveThread(id: thread.id, atEncounter: 3)

    let active = manager.activeThreads(currentEncounter: 3)
    #expect(active.isEmpty)

    #expect(manager.threads[0].resolved)
    #expect(manager.threads[0].resolvedAt == 3)
}

@Test("Overdue thread detection")
func testOverdueThreads() {
    var manager = ThreadManager()

    let thread = manager.createThread(description: "test thread", currentEncounter: 1, windowSize: 2)

    // Not overdue yet
    #expect(manager.overdueThreads().isEmpty)

    // Simulate passage of time
    let active = manager.activeThreads(currentEncounter: 5)
    #expect(active.isEmpty)  // Thread should be filtered out

    #expect(!manager.overdueThreads().isEmpty)
}

@Test("Auto-detection of thread resolution")
func testAutoDetection() {
    var manager = ThreadManager()
    let thread = manager.createThread(description: "crow totem mystery", currentEncounter: 1, windowSize: 3)

    let narrative = "You discover the ancient crow totem hidden beneath the altar. The mystery is finally solved."

    // Simulate auto-detection logic
    let keywords = thread.description.lowercased().split(separator: " ")
    let lower = narrative.lowercased()
    let matches = keywords.filter { lower.contains($0) }.count
    let ratio = Double(matches) / Double(keywords.count)

    #expect(ratio > 0.5)  // Should auto-resolve
}
```

**Integration Tests:**
```swift
@Test("Threads persist across save/load", .enabled(if: isLLMAvailable()))
func testThreadPersistence() async throws {
    try? await Task.sleep(for: .milliseconds(500))
    let engine = MockGameEngine(mode: .llm)

    await setupGameWithAdventure(engine, preferredType: .dungeon)

    // Create a thread
    let thread = engine.threadManager.createThread(
        description: "mysterious door",
        currentEncounter: 1,
        windowSize: 3
    )

    // Save
    engine.saveState()

    // Load into new engine
    let engine2 = MockGameEngine(mode: .llm)
    try engine2.loadState()

    #expect(engine2.threadManager.threads.count == 1)
    #expect(engine2.threadManager.threads[0].description == "mysterious door")
}

@Test("Thread context passed to LLM", .enabled(if: isLLMAvailable()))
func testThreadContext() async throws {
    try? await Task.sleep(for: .milliseconds(500))
    let engine = MockGameEngine(mode: .llm)

    await setupGameWithAdventure(engine, preferredType: .dungeon)

    // Create thread
    engine.threadManager.createThread(
        description: "glowing runes",
        currentEncounter: engine.adventureProgress?.currentEncounter ?? 1,
        windowSize: 3
    )

    // Take a turn
    await engine.submitPlayer(input: "examine the area")

    // Check that last prompt contained thread info
    #expect(engine.lastPrompt?.contains("Threads:") ?? false)
    #expect(engine.lastPrompt?.contains("glowing runes") ?? false)
}
```

**Manual Test Cases:**
1. Start adventure → manually create thread via debug UI
2. Play 3 turns → verify thread appears in context
3. Resolve thread (auto or manual) → verify removed from active list
4. Let thread go overdue → verify logging shows warning
5. Save/load with active threads → verify threads persist
6. Complete adventure with unresolved threads → verify cleanup

**Acceptance Criteria:**
- ✅ Threads created and tracked correctly
- ✅ Active threads (max 2) passed to Adventure LLM
- ✅ Auto-detection resolves threads when keywords match
- ✅ Manual resolution via `resolvedThreads` field works
- ✅ Overdue threads logged as warnings
- ✅ Threads persist across save/load
- ✅ Cleanup removes resolved threads

---

### 4.4 Refinement (Days 11-12)

**Add automatic thread creation from NPCs:**
```swift
// When NPC makes a promise or mentions something important
func autoCreateThreadFromNPC(npc: NPCDefinition, dialogue: String, currentEncounter: Int) {
    let promiseKeywords = ["will", "shall", "promise", "swear", "tomorrow", "later", "soon", "return"]
    let lower = dialogue.lowercased()

    for keyword in promiseKeywords {
        if lower.contains(keyword) {
            // Extract a short description from dialogue
            let description = extractThreadDescription(from: dialogue, npc: npc)
            let thread = threadManager.createThread(
                description: description,
                currentEncounter: currentEncounter,
                windowSize: 3
            )
            logger.debug("[Threads] Auto-created from NPC: \(thread.id) '\(thread.description)'")
            break
        }
    }
}

private func extractThreadDescription(from dialogue: String, npc: NPCDefinition) -> String {
    // Simple extraction: NPC name + first significant phrase
    let sentences = dialogue.components(separatedBy: CharacterSet(charactersIn: ".!?"))
    if let firstSentence = sentences.first {
        let words = firstSentence.split(separator: " ").prefix(5).joined(separator: " ")
        return "\(npc.name): \(words)"
    }
    return "\(npc.name) promise"
}
```

**Add thread priority system:**
```swift
extension OpenThread {
    var priority: Int {
        // Higher priority = closer to deadline
        if turnsRemaining <= 0 { return 100 }  // Overdue
        if turnsRemaining == 1 { return 50 }   // Urgent
        if turnsRemaining == 2 { return 25 }   // Soon
        return 10  // Normal
    }
}

// Update activeThreads to use priority
func activeThreads(currentEncounter: Int) -> [OpenThread] {
    return threads.filter { !$0.resolved && !$0.isOverdue }
        .sorted { $0.priority > $1.priority }
}
```

**Add thread closure rate tracking:**
```swift
struct ThreadMetrics {
    var totalCreated: Int = 0
    var totalResolved: Int = 0
    var resolvedOnTime: Int = 0
    var resolvedLate: Int = 0

    var closureRate: Double {
        guard totalCreated > 0 else { return 0 }
        return Double(totalResolved) / Double(totalCreated)
    }

    var onTimeRate: Double {
        guard totalResolved > 0 else { return 0 }
        return Double(resolvedOnTime) / Double(totalResolved)
    }
}

// Track metrics in ThreadManager
mutating func resolveThread(id: String, atEncounter: Int) {
    if let index = threads.firstIndex(where: { $0.id == id }) {
        threads[index].resolved = true
        threads[index].resolvedAt = atEncounter

        metrics.totalResolved += 1
        if atEncounter <= threads[index].dueBy {
            metrics.resolvedOnTime += 1
        } else {
            metrics.resolvedLate += 1
        }
    }
}
```

---

### 4.5 Documentation (Days 13-14)

Update `CLAUDE.md`:
```markdown
### Open Threads System

**Purpose:** Track narrative promises and ensure resolution within time windows.

**Schema:**
```swift
struct OpenThread {
    var id: String              // "T1", "T2", etc.
    var description: String     // "crow totem mystery"
    var introducedAt: Int       // Encounter number
    var dueBy: Int             // introducedAt + windowSize (default 3)
    var resolved: Bool
    var windowSize: Int        // Default: 3 encounters
}
```

**Thread Lifecycle:**
1. **Creation:** Manual (LLM via `newThreads`) or auto (NPC promises, item mentions)
2. **Active:** Passed to Adventure LLM in context (max 2 threads)
3. **Resolution:** Auto-detection (keyword matching) or manual (LLM via `resolvedThreads`)
4. **Overdue:** Logged as warning if not resolved within window

**Context Format:**
```
Threads: T12 "crow totem" (due in 2), T7 "old well rumor" (due in 1)
```

**LLM Instructions (adventure.txt):**
```
THREADS (optional narrative promises):
If "Threads:" present, reference ≥1 thread ID in output.
Mark resolved via resolvedThreads field when promise fulfilled.
Create new threads via newThreads field for new mysteries/promises.
```

**Metrics Tracked:**
- Total threads created
- Total resolved
- On-time resolution rate (target: >80%)
- Closure rate (target: >80%)

**Examples:**
- NPC says "I'll have news tomorrow" → auto-create thread
- Narrative mentions "ancient door" but don't open → potential thread
- Thread "crow totem" resolved when narrative says "you find the totem"
```

Update `LLM_SYSTEM.md`:
Add new section after "Narrative Sanitization":
```markdown
## Open Threads System

**Problem:** Narratives introduce mysteries/promises without resolving them (Chekhov's gun violations).

**Solution:** Track open threads with due dates, pass to LLM, auto-detect resolution.

### Thread Tracking
```swift
struct OpenThread {
    var id: String              // "T1"
    var description: String     // "crow totem mystery"
    var introducedAt: Int       // Encounter 1
    var dueBy: Int             // Encounter 4 (introducedAt + 3)
    var resolved: Bool
}
```

### Thread Sources
1. **LLM Output:** `newThreads: ["mysterious door"]`
2. **Auto-Creation:** NPC promises, item mentions, location references
3. **Manual:** Debug/testing

### Context Injection
Max 2 active threads passed to Adventure LLM:
```
Threads: T12 "crow totem" (due in 2), T7 "old well rumor" (due in 1)
```

### Resolution
1. **Auto-Detection:** Keyword matching (>50% keywords in narrative)
2. **Manual:** LLM sets `resolvedThreads: ["T12"]`
3. **Overdue:** Logged as warning if not resolved by due date

### Metrics
- Closure rate: totalResolved / totalCreated (target >80%)
- On-time rate: resolvedOnTime / totalResolved (target >80%)
```

Create new test file:
```swift
// DunGenTests/ThreadManagerTests.swift
import Testing
@testable import DunGen

struct ThreadManagerTests {
    @Test("Thread lifecycle")
    func testThreadLifecycle() {
        var manager = ThreadManager()

        // Create
        let thread = manager.createThread(description: "test", currentEncounter: 1, windowSize: 3)
        #expect(manager.threads.count == 1)

        // Active
        let active = manager.activeThreads(currentEncounter: 2)
        #expect(active.count == 1)
        #expect(active[0].turnsRemaining == 2)

        // Resolve
        manager.resolveThread(id: thread.id, atEncounter: 3)
        #expect(manager.activeThreads(currentEncounter: 3).isEmpty)

        // Metrics
        #expect(manager.metrics.closureRate == 1.0)
    }

    @Test("Overdue detection")
    func testOverdue() {
        var manager = ThreadManager()
        manager.createThread(description: "test", currentEncounter: 1, windowSize: 2)

        // At encounter 5, thread is overdue (due by encounter 3)
        let overdue = manager.overdueThreads()
        #expect(!overdue.isEmpty)
    }

    @Test("Priority sorting")
    func testPriority() {
        var manager = ThreadManager()

        let t1 = manager.createThread(description: "urgent", currentEncounter: 1, windowSize: 1)
        let t2 = manager.createThread(description: "normal", currentEncounter: 1, windowSize: 5)

        let active = manager.activeThreads(currentEncounter: 1)
        #expect(active[0].id == t1.id)  // Urgent comes first
    }
}
```

---

## Post-Implementation

### Week 5: Integration Testing
**Test all 4 features together:**
1. Full playthrough (15+ turns) with all features enabled
2. Verify CC maintains consistency
3. Verify beat templates improve structure
4. Verify linter produces quality output
5. Verify threads get created and resolved

**Metrics to Track:**
- CC drift violations: <1%
- Beat template compliance: >80%
- Linter corrections per turn: average count
- Thread closure rate: >80%
- Thread on-time rate: >80%

---

### Week 6: Polish & Documentation
1. Fix any bugs found in integration testing
2. Tune thresholds (thread window size, linter aggressiveness)
3. Update all documentation
4. Create tutorial/guide for understanding the new systems
5. Add debug UI for threads (optional)

---

## Success Criteria

**Phase 1 (CC):**
- ✅ No POV drift (always second person)
- ✅ No tense drift (always present)
- ✅ No time/weather drift mid-adventure
- ✅ Location changes only when quest completes

**Phase 2 (Beats):**
- ✅ >80% turns follow beat templates
- ✅ Sensory details in >90% turns
- ✅ ≤1 proper noun per turn
- ✅ 2-4 sentences, ≤85 words

**Phase 3 (Linter):**
- ✅ Zero third-person pronouns in output
- ✅ Zero raw stats (HP/XP/gold numbers) in narrative
- ✅ Item acquisition verbs moved to actions
- ✅ Proper noun count ≤1

**Phase 4 (Threads):**
- ✅ Threads created from NPC promises
- ✅ >80% threads resolved within window
- ✅ Overdue threads logged
- ✅ Thread context passed to LLM

---

## Rollback Plan

Each phase is independent and can be disabled via feature flag:

```swift
// LLMGameEngine.swift
struct NarrativeFeatures {
    static var useConsistencyContract = true
    static var useBeatTemplates = true
    static var useNarrativeLinter = true
    static var useOpenThreads = true
}

// Disable specific feature if issues arise
if NarrativeFeatures.useConsistencyContract {
    // Apply CC
}
```

---

## Timeline Summary

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1: CC | 1 week | Consistency contract prevents drift |
| Phase 2: Beats | 1 week | Structured narrative with templates |
| Phase 3: Linter | 1 week | Deterministic quality improvements |
| Phase 4: Threads | 2 weeks | Narrative promises tracked & resolved |
| Integration | 1 week | All features working together |
| Polish | 1 week | Bug fixes, tuning, documentation |
| **Total** | **7 weeks** | **Production-ready narrative system** |

---

## Next Steps

1. Review and approve plan
2. Create feature branches for each phase
3. Start Phase 1 implementation
4. Test thoroughly before moving to next phase
5. Iterate based on real gameplay testing
