# PROMPTS.md

**Purpose**: Documentation of DunGen's LLM prompt engineering system, including input construction, output sanitization, and context management strategies.

---

## Game Overview

DunGen is an iOS text-based RPG that uses Apple's on-device LLM (FoundationModels framework) to generate dynamic narratives, characters, and encounters. The game features:

- **Permadeath rogue-like** with quest-based adventures
- **16 character classes** across 8 races
- **112 base monsters** + deterministic affix system
- **6 quest types**: Combat, Retrieval, Escort, Investigation, Rescue, Diplomatic
- **Strict 4096 token context window** requiring aggressive optimization
- **8 specialist LLMs** working in sequence to generate coherent gameplay

**Core Challenge**: Maintain narrative consistency and mechanical correctness while operating within Apple's 4096-token limit per LLM session.

---

## Specialist LLMs - Purpose & Goals

### 1. **World Specialist**
**Purpose**: Generate immersive fantasy worlds with diverse starting locations
**Goals**:
- Create 2-5 starting locations (outdoor, village, dungeon, city)
- Establish overarching world narrative (2-3 sentences)
- Provide location variety for replayability
- Maintain thematic consistency across locations

**Input**: Simple prompt requesting world generation
**Output**: `WorldState` with world story + location array

---

### 2. **Character Specialist**
**Purpose**: Create unique level 1 characters for new games
**Goals**:
- Generate name, race, class combination
- Assign class-appropriate stats (STR, DEX, CON, INT, WIS, CHA)
- Provide starting equipment matching class archetype
- Create brief backstory and personality
- Ensure name uniqueness (post-generation verification)

**Input**: Race + class combination
**Output**: `CharacterProfile` with full stats, inventory, abilities/spells

---

### 3. **Encounter Specialist**
**Purpose**: Determine encounter type and difficulty for each turn
**Goals**:
- Select appropriate encounter type (combat, social, exploration, puzzle, trap, stealth, chase, final)
- Scale difficulty based on character level
- Enforce variety (no consecutive combat, 3+ encounters between traps)
- Match encounter to location theme
- Identify final encounters for quest completion

**Input**: Minimal context (encounter history count summary)
**Output**: `EncounterDetails` with type + difficulty

---

### 4. **Adventure Specialist** (Primary Narrative)
**Purpose**: Generate 2-4 sentence narrative text describing the current scene
**Goals**:
- **CRITICAL**: Stay under 400 characters (strictly enforced)
- Write in 2nd person ("you"), never 3rd person ("he/she/the hero")
- Reference quest goal and progression stage
- Describe immediate situation without suggesting player actions
- Present quest objectives clearly at final encounter
- Include `adventureProgress` in every response

**Input**: Tiered context (character, quest, location, encounter type, monster/NPC if present)
**Output**: `AdventureTurn` with narration, adventureProgress, suggestedActions, itemsAcquired

---

### 5. **NPC Specialist**
**Purpose**: Generate and manage persistent non-player characters
**Goals**:
- Create unique NPCs with name, occupation, personality, backstory
- Maintain consistency across multiple interactions
- Track relationship status (neutral, friendly, hostile, allied)
- Generate contextually appropriate dialogue
- Vary mood and speech patterns
- Avoid duplicate NPCs at same location

**Input**: Location + difficulty context
**Output**: `NPCDefinition` with identity, dialogue, mood, questHook

---

### 6. **Abilities Specialist**
**Purpose**: Generate physical abilities for characters (non-casters or physical skills)
**Goals**:
- Create class-appropriate physical abilities
- Match character level and power scaling
- Provide mechanical effects (damage, defense, utility)
- Keep descriptions concise

**Input**: Character class + level
**Output**: `CharacterAbility` array

---

### 7. **Spells Specialist**
**Purpose**: Generate arcane/nature/death/eldritch spells for caster classes
**Goals**:
- Create appropriate spell types (Mage: arcane, Druid: nature, Necromancer: death, Warlock: eldritch)
- Scale power with character level
- Provide clear mechanical effects
- Maintain class fantasy

**Input**: Character class + level + spell type
**Output**: `CharacterSpell` array

---

### 8. **Prayers Specialist**
**Purpose**: Generate divine prayers for divine classes (Healer, Paladin, Cleric)
**Goals**:
- Create divine-themed prayers (healing, protection, holy power)
- Match class identity
- Scale with character level

**Input**: Character class + level
**Output**: `CharacterPrayer` array

---

## Eliminated LLMs (Now Code-Based)

The following specialists were **removed** and replaced with deterministic code to improve consistency and reduce context usage:

- **Progression LLM** → `RewardCalculator` (deterministic XP/gold formulas)
- **Equipment LLM** → `ItemAffixGenerator` (100 prefixes/suffixes from `AffixDatabase`)
- **Monster LLM** → `MonsterAffixGenerator` (100 prefixes/suffixes from `AffixDatabase`)

---

## Context Management Strategy

### Challenge: 4096 Token Budget

Apple's on-device LLM has a **strict 4096 token limit** (~16,384 characters). Context includes:
- System instructions (fixed)
- Conversation history (grows each turn)
- Current prompt (dynamic)
- Response buffer (reserved ~200 tokens)

### Token Budget Allocation

| Component | Tokens | Notes |
|-----------|--------|-------|
| Instructions | ~90-234 | Compressed instruction files |
| History | Growing | Past prompts + responses |
| Current Prompt | Dynamic | Calculated per turn |
| Response Buffer | ~200 | Reserved for LLM output |
| Safety Margin | ~50 | Prevents overflow |

### Context Strategies

#### 1. **Tiered Context System** (`ContextBuilder.swift`)

Each specialist receives **only the context it needs**:

```swift
switch specialist {
case .encounter:
    // Minimal: just encounter count summary
    return "Total encounters: 12 (combat: 5, social: 4, exploration: 3)"

case .adventure:
    // Standard: character, quest, location, encounter type, history
    return """
    Char: Thorin L3 Warrior HP:18 G:42
    Loc: dungeon
    Quest: Retrieve the stolen crown from the bandit hideout
    Enc: combat (hard)
    Recent: attacked the guard
    Hist: 5 enc (2 combat, 2 social, 1 exploration)
    STAGE-FINALE: Present the crown. Offer "Take the Crown of Kings"
    """

case .monsters:
    // Minimal: just location, difficulty, level
    return "Loc: dungeon\nDiff: hard\nLvl: 3"

case .npc:
    // Minimal: location + difficulty
    return "Loc: village\nDiff: normal"
}
```

**Benefits**:
- Encounter LLM: ~85 tokens/exchange
- Adventure LLM: ~234 tokens/exchange (most complex)
- Monster/NPC LLMs: ~85 tokens/exchange
- Others: ~70-140 tokens/exchange

#### 2. **Compressed Labels**

Use abbreviations in prompts:
- `Char:` instead of `Character:`
- `Loc:` instead of `Location:`
- `Enc:` instead of `Encounter:`
- `Hist:` instead of `History:`
- `G:` instead of `Gold:`

Saves ~5-10 characters per line.

#### 3. **Ultra-Compressed Instructions**

All instruction files reduced by 50-97%:

| File | Original | Compressed | Reduction |
|------|----------|------------|-----------|
| adventure.txt | 7,575 chars | 936 chars | **97%** |
| encounter.txt | 1,885 chars | 340 chars | **82%** |
| world.txt | - | 591 chars | N/A |
| character.txt | - | 2,403 chars | N/A |
| npc.txt | - | 3,527 chars | N/A |

**Compression techniques**:
- Bullet points instead of prose
- Remove examples (rely on @Generable type constraints)
- Use abbreviations and acronyms
- Critical rules marked with ⚠️

#### 4. **Smart Prompt Truncation** (`NarrativeProcessor.smartTruncatePrompt()`)

When prompts exceed max length, prioritize content:

**Tier 1 (Always Keep)**:
- ⚠️ CRITICAL instructions
- STAGE- quest progression markers
- NEW ADVENTURE signals
- AVOID QUEST TYPES (variety enforcement)
- Player action
- Encounter type
- Monster info (if present)
- NPC info (if present)

**Tier 2 (Keep if space allows)**:
- Quest goal (<120 chars)
- Location (<50 chars)
- Character stats (<80 chars)

**Tier 3 (Dropped first)**:
- Recent actions history
- Encounter count statistics
- Long descriptions

#### 5. **Dynamic Prompt Sizing** (`TokenEstimator`)

Adventure LLM calculates safe prompt size before each turn:

```swift
let instructionTokens = estimateTokens(instructions) // ~234
let historyTokens = estimateTokens(conversationHistory) // grows
let responseBuffer = 200 // reserved
let safetyMargin = 50
let maxPromptTokens = 4096 - instructionTokens - historyTokens - responseBuffer - safetyMargin
```

Logs detailed breakdown:
```
[Adventure] Token Budget:
  Total: 4096
  Instructions: 234 tokens
  History: 1136 tokens (4 exchanges)
  Response Buffer: 200 tokens
  Safety Margin: 50 tokens
  Available for Prompt: 2476 tokens (~9,904 chars)
```

#### 6. **Session Reset Thresholds**

Each specialist resets conversation history when reaching token budget:

| Specialist | Reset After | Rationale |
|------------|-------------|-----------|
| Adventure | 6 uses | Largest prompts (~568 tokens/exchange) |
| Encounter | 15 uses | Small prompts (~253 tokens/exchange) |
| Monster | 15 uses | Small prompts (~253 tokens/exchange) |
| NPC | 15 uses | Small prompts (~253 tokens/exchange) |
| Equipment | 10 uses | Medium prompts (~380 tokens/exchange) |
| Others | 20 uses | Small prompts (~190 tokens/exchange) |

**Global safety**: Reset ALL sessions every 15 turns as backup.

#### 7. **Response Length Enforcement**

Adventure LLM strictly limited to **2-4 sentences (max 400 chars)**:

```
⚠️ 2-4 SHORT sentences (max 400 chars). Stop after 4.
```

**Why critical**: Observed responses reached ~425 tokens without constraints, risking context overflow. Strict enforcement prevents token budget violations.

#### 8. **Post-Generation Verification**

For locations, NPCs, abilities, spells:
1. Generate WITHOUT listing existing items (saves context)
2. Check for duplicates in code
3. If duplicate, regenerate with exclusion list (only duplicates, not full history)
4. Max 5-10 attempts before fallback

**Example**:
```swift
// First attempt: no existing NPCs mentioned
let npc1 = generateNPC(prompt: "Create an NPC")

// Duplicate detected: "Garrick" already exists
// Second attempt: only exclude duplicate
let npc2 = generateNPC(prompt: "Create an NPC. AVOID: Garrick")
```

---

## Prompt Construction Flow

### Turn Sequence (advanceScene)

1. **Player submits action** → truncated to 500 chars
2. **Session management** → increment turn count, reset if needed
3. **Encounter generation**:
   ```swift
   let encounterContext = ContextBuilder.buildContext(
       for: .encounter,
       encounterCounts: encounterCounts
   )
   let encounter = try await encounterSession.respond(
       to: encounterContext,
       generating: EncounterDetails.self
   )
   ```

4. **Monster/NPC generation** (if applicable):
   ```swift
   if encounter.encounterType == "combat" {
       let monsterContext = ContextBuilder.buildContext(
           for: .monsters,
           characterLevel: charLevel,
           location: location,
           difficulty: encounter.difficulty
       )
       monster = try await generateMonster(context: monsterContext)
   } else if encounter.encounterType == "social" {
       npc = try await generateOrRetrieveNPC(location: location)
   }
   ```

5. **Adventure narrative generation**:
   ```swift
   // Build context
   let adventureContext = ContextBuilder.buildContext(
       for: .adventure,
       character: character,
       characterLevel: charLevel,
       adventure: adventureProgress,
       location: location,
       encounterType: encounter.encounterType,
       difficulty: encounter.difficulty,
       recentActions: recentActionsString,
       encounterCounts: encounterCounts,
       recentQuestTypes: recentQuestTypes,
       questProgressGuidance: questProgressManager.getGuidance(...)
   )

   // Calculate safe prompt size
   let maxPromptSize = calculateMaxSafePromptSize(
       instructionSize: adventureInstructions.count,
       historySize: conversationHistory.count
   )

   // Truncate if needed
   let finalPrompt = smartTruncatePrompt(adventureContext, maxLength: maxPromptSize)

   // Add monster/NPC context
   if let monster = monster {
       finalPrompt += "\nMonster: \(monster.fullName) - \(monster.appearance)"
   }
   if let npc = npc {
       finalPrompt += "\nNPC: \(npc.name) (\(npc.occupation)) - \(npc.appearance)"
   }

   // Generate narrative
   let turn = try await adventureSession.respond(
       to: finalPrompt,
       generating: AdventureTurn.self
   )
   ```

6. **Output sanitization**:
   ```swift
   let sanitizedNarration = narrativeProcessor.sanitizeNarration(
       turn.narration,
       for: encounter.encounterType,
       expectedMonster: monster
   )
   ```

7. **Apply game state changes** via `TurnProcessor`:
   - Update adventure progress
   - Handle quest completion
   - Apply XP/gold/HP rewards
   - Distribute loot
   - Track encounter history

---

## Output Sanitization

### Narrative Sanitization (`NarrativeProcessor`)

#### 1. **Combat Verb Removal**

**Problem**: Adventure LLM sometimes resolves combat in narrative
**Solution**: Replace forbidden verbs with "confront" in combat encounters

```swift
let forbidden = ["defeat", "defeated", "kill", "killed", "slay", "slain",
                 "strike", "struck", "smite", "smitten", "crush", "crushed",
                 "stab", "stabbed", "shoot", "shot", "damage", "wound"]

if encounterType == "combat" || encounterType == "final" {
    for word in forbidden {
        sanitized = sanitized.replacingOccurrences(of: word, with: "confront")
    }
}
```

**Why**: Combat resolution handled by dedicated `CombatManager`, not narrative LLM.

#### 2. **Action Suggestion Removal**

**Problem**: LLM sometimes adds questions or action suggestions
**Solution**: Filter out lines containing suggestion patterns

```swift
let hasActionPattern = lower.contains("you could") ||
                      lower.contains("you can") ||
                      lower.contains("you may") ||
                      lower.contains("will you") ||
                      lower.contains("what do you") ||
                      lower.contains("perhaps you") ||
                      lower.contains("options:") ||
                      lower.contains("choices:")

let isQuestionToPlayer = trimmed.hasSuffix("?") && lower.contains("you")

// Remove lines matching these patterns
```

**Why**: Suggested actions provided via separate `suggestedActions` array in JSON.

#### 3. **Monster Reference Validation**

**Problem**: LLM sometimes mentions wrong monster or multiple monsters
**Solution**: Validate monster references against expected monster

```swift
func validateMonsterReferences(in text: String, expectedMonster: MonsterDefinition?) -> String {
    guard let monster = expectedMonster else { return text }

    let expectedWords = Set(monster.fullName.lowercased().split(separator: " "))

    for line in text.components(separatedBy: "\n") {
        if line.containsMonsterKeyword() {
            let hasExpectedWord = expectedWords.contains { line.lowercased().contains($0) }
            if !hasExpectedWord {
                // Replace with generic description
                sanitized = "You sense something in the shadows."
            }
        }
    }

    return sanitized
}
```

**Why**: Ensures narrative consistency with code-generated monsters.

---

## Quest Progression System

### Quest Types & Completion Logic

**6 quest types** with specialized final encounter handling:

#### 1. **Retrieval Quest**
- **Keywords**: find, retrieve, locate, discover
- **Final Encounter**: "final" type (non-combat)
- **Completion**: Player takes artifact via "Take [artifact]" action
- **Code Control**: LLM cannot mark complete, only `TurnProcessor` can

```
STAGE-FINALE: Present the stolen crown on the altar.
Offer "Take the Crown of Kings" action.

Player: "Take the Crown of Kings"
→ TurnProcessor detects completion verb + artifact → marks completed=true
```

#### 2. **Combat Quest**
- **Keywords**: defeat, kill, destroy, stop
- **Final Encounter**: "combat" type with "boss" difficulty
- **Completion**: Boss monster defeated in combat
- **Code Control**: Completion triggered by `CombatManager.performCombatAction()`

#### 3. **Escort Quest**
- **Keywords**: escort, protect, guide
- **Final Encounter**: "final" OR "combat" (hard) if threat
- **Completion**: Destination reached OR final threat defeated

#### 4. **Investigation Quest**
- **Keywords**: investigate, solve, uncover
- **Final Encounter**: "final" type
- **Completion**: Truth revealed, player acknowledges

#### 5. **Rescue Quest**
- **Keywords**: rescue, save, free
- **Final Encounter**: "combat" (hard) OR "final"
- **Completion**: Captive freed (combat win OR unlock action)

#### 6. **Diplomatic Quest**
- **Keywords**: negotiate, persuade, convince, diplomacy
- **Final Encounter**: "social" type (critical negotiation)
- **Completion**: Agreement reached with key NPC

### Quest Progression Guidance (`QuestProgressManager`)

**Purpose**: Guide Adventure LLM through quest stages without bloating prompts

**Stages** (based on encounter progress):

| Stage | Threshold | Guidance | Example (6-enc quest) |
|-------|-----------|----------|----------------------|
| Early | < 50% | "Intro clues/NPCs/hints. Show obstacles, NO artifact yet." | Encounters 1-2 |
| Mid | 50-84% | "Hint at item location. Build tension." | Encounters 3-4 |
| Late | 85-99% | "Show item/location clearly. Prepare for finale." | Encounter 5 |
| Final | 100% | Quest-specific completion instructions | Encounter 6 |

**Final Stage Instructions** (injected into Adventure LLM context):

- **Retrieval**: `"STAGE-FINALE: Present [artifact]. Offer 'Take [artifact]' action."`
- **Combat**: `"STAGE-FINALE: Boss encounter. Victory completes quest."`
- **Escort**: `"STAGE-FINALE: Arrive at destination OR defeat final threat."`
- **Investigation**: `"STAGE-FINALE: Reveal solution. Player acknowledges."`
- **Rescue**: `"STAGE-FINALE: Present captive. Free them (combat or unlock)."`
- **Diplomatic**: `"STAGE-FINALE: Critical negotiation. Reach agreement."`

**Integration**:
```swift
let guidance = questProgressManager.getGuidance(
    adventure: adventureProgress,
    currentEncounter: currentEncounter,
    totalEncounters: totalEncounters
)

// Guidance automatically appended to Adventure LLM context
let adventureContext = ContextBuilder.buildContext(
    ...,
    questProgressGuidance: guidance
)
```

### Quest Variety Enforcement

**Problem**: LLM may repeat similar quest types
**Solution**: Track last 5 completed quest types, pass to Adventure LLM for new quests

```swift
// After quest completion
recentQuestTypes.append(questType) // "retrieval", "combat", etc.
if recentQuestTypes.count > 5 {
    recentQuestTypes.removeFirst()
}

// On new adventure start
if adventure == nil {
    context += "\nAVOID QUEST TYPES: \(recentQuestTypes.joined(separator: ", "))"
}
```

**Result**: Encourages variety across consecutive adventures.

---

## Special Cases & Edge Cases

### 1. **Empty Player Action**

When location selected for first adventure:
```swift
playerAction = "" // empty string
actionLine = playerAction.map { "Player action: \($0)" } ?? "Begin scene"
// Result: "Begin scene"
```

### 2. **Monster Name Reuse Prevention**

**Problem**: LLM might reuse defeated monster names
**Solution**: Track defeated monsters, pass to context

```swift
let defeatedNames = defeatedMonsters.suffix(5).map { $0.fullName }
context += "\nNO reused defeated monster names: \(defeatedNames.joined(separator: ", "))"
```

### 3. **Affix Variety Tracking**

**Problem**: Items/monsters with repeated affixes feel repetitive
**Solution**: Track last 10 prefixes + 10 suffixes separately

```swift
affixRegistry.trackItemAffix(prefix: "Flaming", type: .prefix)
affixRegistry.trackItemAffix(suffix: "of Speed", type: .suffix)

let recentPrefixes = affixRegistry.getRecentAffixes(type: .prefix, limit: 10)
let recentSuffixes = affixRegistry.getRecentAffixes(type: .suffix, limit: 10)
```

Passed to Equipment LLM to encourage variety.

### 4. **NPC Conversation Limits**

**Problem**: Extended NPC conversations bloat transcript
**Solution**: Limit to 2 turns unless explicitly referenced

```swift
let isContinuingConversation =
    activeNPC != nil &&
    activeNPCTurns < 2 &&
    playerAction?.lowercased().contains(activeNPC.name.lowercased()) == true

if isContinuingConversation {
    // Continue with same NPC
} else {
    // End conversation, generate new encounter
    activeNPC = nil
    activeNPCTurns = 0
}
```

### 5. **Combat Encounter Isolation**

**Problem**: Item acquisition during combat causes UI conflicts
**Solution**: Block loot generation during combat encounters

```swift
if encounter.encounterType != "combat" {
    loot = await generateLoot(difficulty: encounter.difficulty, characterLevel: charLevel)
}
```

### 6. **Character Death Validation**

**Problem**: Quest completion while dead creates inconsistency
**Solution**: Validate character is alive before marking quest complete

```swift
func handleFinalEncounterCompletion() async {
    guard let char = character, char.hp > 0 else {
        logger.warning("Character died - quest completion denied")
        adventureProgress?.completed = false
        return
    }

    // Proceed with completion
}
```

---

## Prompt Examples

### Example 1: First Turn of New Adventure (Retrieval Quest)

**Encounter LLM Input**:
```
First encounter
```

**Encounter LLM Output**:
```json
{
  "encounterType": "exploration",
  "difficulty": "normal"
}
```

**Adventure LLM Input**:
```
Char: Elara L1 Rogue HP:12 G:15
Loc: village
NEW ADVENTURE - Generate new quest goal for this location
Enc: exploration (normal)
AVOID QUEST TYPES: combat, retrieval
STAGE-EARLY: Intro clues/NPCs/hints. Show obstacles, NO artifact yet.
```

**Adventure LLM Output**:
```json
{
  "narration": "You arrive in the village of Millhaven, where nervous whispers fill the air. The mayor's daughter has vanished, and locals fear foul play.",
  "adventureProgress": {
    "locationName": "Millhaven",
    "adventureStory": "Investigate the disappearance of the mayor's daughter",
    "questGoal": "Rescue the mayor's daughter from her captors",
    "currentEncounter": 1,
    "totalEncounters": 7,
    "completed": false
  },
  "suggestedActions": ["Talk to the mayor", "Ask villagers", "Examine the town square"],
  "itemsAcquired": null,
  "goldSpent": 0
}
```

**Sanitized Output**:
```
You arrive in the village of Millhaven, where nervous whispers fill the air. The mayor's daughter has vanished, and locals fear foul play.

🎯 Quest: Rescue the mayor's daughter from her captors
📍 Location: Millhaven
```

---

### Example 2: Combat Encounter with Monster

**Encounter LLM Input**:
```
Total encounters: 5 (exploration: 2, social: 2, combat: 1)
```

**Encounter LLM Output**:
```json
{
  "encounterType": "combat",
  "difficulty": "hard"
}
```

**Monster Generation** (code-based, not LLM):
```swift
// MonsterGenerator selects base monster + applies affixes
let baseMonster = MonsterDatabase.monsters[level1to3].randomElement()
let affixedMonster = MonsterAffixGenerator.applyAffixes(
    to: baseMonster,
    difficulty: "hard",
    characterLevel: 2,
    avoidAffixes: affixRegistry.getRecentAffixes(type: .monster, limit: 10)
)
// Result: "Venomous Cave Rat" (base: Cave Rat, prefix: Venomous)
```

**Adventure LLM Input**:
```
Char: Elara L2 Rogue HP:15 G:42
Loc: dungeon
Quest: Retrieve the stolen amulet from the bandit hideout
Enc: combat (hard)
Recent: opened the hidden door
Hist: 5 enc (2 exploration, 2 social, 1 combat)
STAGE-MID: Hint at item location. Build tension.
Monster: Venomous Cave Rat - A diseased rat with glowing green eyes and dripping fangs
```

**Adventure LLM Output**:
```json
{
  "narration": "As you descend into the damp tunnels, a hissing sound echoes. A Venomous Cave Rat emerges from the shadows, blocking your path with bared fangs.",
  "adventureProgress": {
    "locationName": "Bandit Hideout",
    "adventureStory": "Infiltrate the hideout and reclaim the stolen amulet",
    "questGoal": "Retrieve the stolen amulet from the bandit hideout",
    "currentEncounter": 5,
    "totalEncounters": 8,
    "completed": false
  },
  "suggestedActions": ["Attack the rat", "Sneak past", "Use an item"],
  "itemsAcquired": null,
  "goldSpent": 0
}
```

**Sanitized Output** (combat verb removal):
```
As you descend into the damp tunnels, a hissing sound echoes. A Venomous Cave Rat emerges from the shadows, blocking your path with bared fangs.

🗡️ Monster Encounter: Venomous Cave Rat
HP: 28 | Defense: 3
Abilities: Poison Bite, Diseased Claws, Evasive
```

---

### Example 3: Final Encounter (Retrieval Quest)

**Encounter LLM Input**:
```
Total encounters: 7 (combat: 3, exploration: 2, social: 2)
```

**Encounter LLM Output**:
```json
{
  "encounterType": "final",
  "difficulty": "normal"
}
```

**Adventure LLM Input**:
```
Char: Elara L3 Rogue HP:18 G:67
Loc: dungeon
Quest: Retrieve the stolen amulet from the bandit hideout
Enc: final (normal)
Recent: defeated the bandit captain
Hist: 8 enc (3 combat, 2 exploration, 2 social, 1 trap)
STAGE-FINALE: Present the amulet. Offer "Take the Stolen Amulet" action.
```

**Adventure LLM Output**:
```json
{
  "narration": "In the chamber's center, resting on a stone pedestal, you see the Stolen Amulet glinting in the torchlight. The way is clear.",
  "adventureProgress": {
    "locationName": "Bandit Hideout",
    "adventureStory": "Infiltrate the hideout and reclaim the stolen amulet",
    "questGoal": "Retrieve the stolen amulet from the bandit hideout",
    "currentEncounter": 8,
    "totalEncounters": 8,
    "completed": false
  },
  "suggestedActions": ["Take the Stolen Amulet", "Examine the pedestal", "Look around"],
  "itemsAcquired": null,
  "goldSpent": 0
}
```

**Player Action**: `"Take the Stolen Amulet"`

**Quest Completion** (code-triggered):
```swift
// TurnProcessor.handleQuestCompletion detects completion verb + artifact
let hasCompletionVerb = action.lowercased().contains("take")
let hasArtifactInAction = action.lowercased().contains("amulet")

if hasCompletionVerb && hasArtifactInAction {
    adventureProgress.completed = true
    appendModel("\n✅ Quest Objective Achieved!")
}
```

---

## Best Practices Summary

### For Instruction Files
1. **Use bullet points** instead of paragraphs
2. **Mark critical rules** with ⚠️ emoji
3. **Remove examples** (rely on @Generable type constraints)
4. **Use abbreviations** (DIFF, Enc, Lvl, etc.)
5. **Keep under 1000 chars** when possible

### For Context Building
1. **Provide only relevant context** to each specialist
2. **Use compressed labels** (Char:, Loc:, Enc:)
3. **Prioritize critical info** (quest, monster, NPC)
4. **Drop history first** if truncation needed
5. **Calculate safe prompt sizes** dynamically

### For Output Processing
1. **Always sanitize** narrative text
2. **Validate monster references** against expected monster
3. **Remove action suggestions** (use suggestedActions array)
4. **Enforce response length** strictly (2-4 sentences)
5. **Verify JSON structure** before applying to game state

### For Session Management
1. **Reset based on token budget**, not arbitrary turn counts
2. **Log transcript metrics** after each use (helps debug)
3. **Warn at 85% context usage** (3500 tokens)
4. **Global reset every 15 turns** as safety net
5. **Add 500ms delay** between LLM tests (prevent session conflicts)

---

## Files Reference

### Core Prompt System
- **Instruction Files**: `DunGen/Resources/LLMInstructions/*.txt`
- **Context Builder**: `DunGen/Managers/ContextBuilder.swift`
- **Narrative Processor**: `DunGen/Managers/NarrativeProcessor.swift`
- **Session Manager**: `DunGen/Managers/SpecialistSessionManager.swift`
- **Token Estimator**: `DunGen/Utilities/TokenEstimator.swift`
- **Quest Progress Manager**: `DunGen/Managers/QuestProgressManager.swift`

### Orchestration
- **Main Engine**: `DunGen/LLM/LLMGameEngine.swift`
  - `advanceScene()`: Turn sequence orchestration (line 1178)
  - `apply()`: Game state updates (line 589)
- **Turn Processor**: `DunGen/Managers/TurnProcessor.swift`
  - Quest completion logic (line 62)
  - Reward application (line 190)
- **Encounter Orchestrator**: `DunGen/Managers/EncounterOrchestrator.swift`

### Output Models
- **Adventure Turn**: `DunGen/Models/WorldModels.swift` (AdventureTurn)
- **Encounter Details**: `DunGen/Models/EncounterModels.swift`
- **Monster Definition**: `DunGen/Models/MonsterModels.swift`
- **NPC Definition**: `DunGen/Models/NPCModels.swift`
- **Character Profile**: `DunGen/Models/CharacterModels.swift`

---

## Future Optimization Ideas

1. **Instruction Templates**: Further compress instructions using template syntax
2. **Semantic Chunking**: Split adventure history into semantic chunks rather than full transcript
3. **Encounter Summaries Only**: Replace full conversation history with 1-sentence summaries
4. **Stateful Context**: Use stateful context tracking (character sheet, quest objectives) instead of repeating
5. **Response Caching**: Cache common responses (world generation, character creation) for reuse
6. **Adaptive Truncation**: Learn which context elements are most important via A/B testing
7. **Prompt Compression**: Experiment with token-level compression techniques

---

**Last Updated**: 2025-10-27
**Context Window**: 4096 tokens (Apple on-device LLM via FoundationModels)
**Compression Target**: 50-80% reduction across all instruction files ✓ Complete
