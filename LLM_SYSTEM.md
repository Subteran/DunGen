# DunGen LLM System Architecture

**Last Updated:** 2025-10-26
**System Overview:** 8 specialized on-device LLMs orchestrated through Apple's FoundationModels framework

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Core Principles](#core-principles)
3. [Specialist LLMs](#specialist-llms)
4. [Turn Workflow](#turn-workflow)
5. [Context Management](#context-management)
6. [Code-Based Systems](#code-based-systems)
7. [Session Management](#session-management)
8. [Narrative Sanitization](#narrative-sanitization)

---

## System Overview

DunGen uses **8 specialized LLMs** instead of a single monolithic model. Each specialist has:
- **Focused responsibility** - narrow domain expertise
- **Dedicated instruction file** - compressed to fit context limits
- **Structured output schema** - `@Generable` macro for type-safe JSON
- **Session management** - automatic resets to prevent context bloat

**Architecture Benefits:**
- **Smaller prompts** - each LLM sees only relevant context
- **Better quality** - specialists excel at focused tasks
- **Deterministic fallbacks** - code replaces unreliable LLM calls where possible
- **Maintainability** - update one specialist without affecting others

---

## Core Principles

### 1. **Specialist Over Generalist**
Each LLM does ONE thing well rather than trying to handle all aspects of game generation.

### 2. **Code Over LLM**
When deterministic logic is possible, use code instead of LLM generation:
- ✅ **Eliminated Progression LLM** → `RewardCalculator` with formulas
- ✅ **Eliminated Equipment generation** → `ItemAffixGenerator` with 100 affixes
- ✅ **Eliminated Monster generation** → `MonsterAffixGenerator` with 100 affixes

### 3. **Context Starvation**
On-device LLMs have ~2000 character total limit. Every system must:
- Compress instructions (50-80% reduction via abbreviations)
- Pass minimal context (tiered system via `ContextBuilder`)
- Truncate aggressively (smart truncation preserves critical directives)
- Reset sessions regularly (every 15 turns globally)

### 4. **Sanitize Everything**
LLMs hallucinate. Post-generation validation:
- Remove action suggestions from narrative
- Validate monster names match expected monster
- Strip combat resolution verbs (fighting happens in combat system)
- Check for duplicate NPCs/locations/abilities

---

## Specialist LLMs

### 1. **World Specialist**
**File:** `world.txt` (523 chars)
**Responsibility:** Generate fantasy worlds with starting locations
**Called:** Game start only

**Output Schema:**
```swift
struct GeneratedWorld: Codable {
    var worldStory: String      // 2-3 sentence overarching narrative
    var locations: [Location]   // 2-5 diverse starting locations
}
```

**Location Requirements:**
- At least one OUTDOOR (forest, plains, mountains)
- At least one VILLAGE (settlement, outpost)
- At least one DUNGEON (cave, ruins, crypt)
- Exactly one CITY (major population center)

**Context Provided:** None (first generation)

---

### 2. **Encounter Specialist**
**File:** `encounter.txt` (118 chars)
**Responsibility:** Determine encounter type and difficulty
**Called:** Every turn (unless continuing NPC conversation)

**Output Schema:**
```swift
struct EncounterDetails: Codable {
    var encounterType: String  // combat, social, exploration, puzzle, trap, stealth, chase, final
    var difficulty: String     // easy, normal, hard, boss
}
```

**Encounter Types:**
- **combat** - Monster fight (triggers Monster specialist or uses pending monster)
- **social** - NPC interaction (triggers NPC specialist)
- **exploration** - Discovery, environment navigation
- **puzzle** - Logic challenges, riddles
- **trap** - Damage-dealing hazard (level-scaled)
- **stealth** - Sneaking, avoiding detection
- **chase** - Pursuit sequences
- **final** - Quest completion encounter (non-combat)

**Variety Enforcement (Code-Based):**
- No consecutive combat encounters
- 3+ encounters between traps
- Tracked via `recentEncounterTypes` (last 5)

**Context Provided:**
```
Total encounters: N (combat: X, social: Y, exploration: Z)
```

---

### 3. **Adventure Specialist**
**File:** `adventure.txt` (359 chars - reduced 95%)
**Responsibility:** Generate narrative text and quest progression
**Called:** Every turn

**Output Schema:**
```swift
struct AdventureTurn: Codable {
    var narration: String               // EXACTLY 2-4 sentences
    var adventureProgress: AdventureProgress?
    var suggestedActions: [String]      // 2-4 player action options
    var currentEnvironment: String?
    var itemsAcquired: [String]?
    var goldSpent: Int?
    var playerPrompt: String?           // Optional flavor text
}
```

**Key Instructions:**
- **2-4 sentences only** - enforced strictly to fit context
- **6 quest types** - combat, retrieval, escort, investigation, rescue, diplomatic
- **Quest variety** - avoid recent quest types (last 5 tracked)
- **Monster handling** - only describe if "Monster:" in context, use EXACT name shown
- **NO suggestions in narrative** - no "Will you", "You could", "What do you"
- **NO combat resolution** - describe monsters appearing only, combat handled separately

**Context Provided (Compressed):**
```
Char: Name L5 Warrior HP:45 G:120
Loc: Dark Forest
Quest: Retrieve the stolen amulet
Enc: exploration (normal)
Recent: searched clearing: found tracks
Hist: 8 enc (3 combat, 2 social, 3 exploration)
Monster: Ancient Goblin Shaman (HP: 28, Damage: 6, Defense: 4)  // if combat encounter
```

**Quest Progression Guidance:**
- **STAGE-EARLY** (0-40%): Introduce clues, NPCs, hints
- **STAGE-MID** (40-85%): Direct progress toward goal
- **⚠ FINAL ENC**: Present quest objective, mark completed=true when achieved
- **⚠ FINALE+N**: Extended finale (3 extra turns max)
- **⚠ LAST CHANCE**: Final opportunity before quest fails

**Sanitization (Post-Generation):**
- Remove action suggestions via `removeActionSuggestions()`
- Validate monster references via `validateMonsterReferences()`
- Replace combat verbs (defeat/kill/strike) with "confront"

---

### 4. **Character Specialist**
**File:** `character.txt` (2,153 chars)
**Responsibility:** Generate unique level 1 characters
**Called:** Game start, permadeath

**Output Schema:**
```swift
struct CharacterProfile: Codable {
    var name: String
    var race: String        // Human, Elf, Dwarf, Halfling, Half-Elf, Half-Orc, Gnome, Ursa
    var className: String   // 16 classes (Rogue, Warrior, Mage, Healer, etc.)
    var personality: String // 1-2 traits
    var backstory: String   // 1-2 sentences
    var hp: Int            // 8-14 based on CON
    var maxHP: Int
    var xp: Int            // 0 starting
    var gold: Int          // 5-25 starting
    var inventory: [String]
    var abilities: [String]
    var spells: [String]    // Mage, Druid, Necromancer only
    var prayers: [String]   // Healer, Paladin only
    // Attributes (STR, DEX, CON, INT, WIS, CHA) applied via RaceModifiers code
}
```

**16 Classes (4×4 grid):**
- Row 0: Rogue, Warrior, Mage, Healer
- Row 1: Paladin, Ranger, Monk, Bard
- Row 2: Druid, Necromancer, Barbarian, Warlock
- Row 3: Sorcerer, Cleric, Assassin, Berserker

**8 Races with Stat Modifiers (Code-Based):**
- Human: No modifiers
- Elf: +2 DEX, +1 INT, +1 WIS, +1 CHA, -1 STR, -1 CON
- Dwarf: +2 CON, +1 STR, +1 WIS, -1 DEX, -1 CHA
- Halfling: +2 DEX, +1 WIS, +1 CHA, -2 STR
- Half-Elf: +2 CHA, +1 DEX
- Half-Orc: +2 STR, +1 CON, -1 INT, -1 CHA
- Gnome: +2 INT, +1 DEX, +1 CON, -1 STR
- Ursa: +2 STR, +2 CON, +1 WIS, -1 DEX, -1 INT

**Starting Inventory (MANDATORY):**
- 3 Healing Potions (5-10 HP each)
- 3 Bandages (2 HP each)
- Class-specific equipment (2-4 items)

**Context Provided:**
```
Race: Dwarf
Class: Warrior
```

**Post-Generation Verification:**
- Check for duplicate names via `usedNames` Set
- Validate abilities don't duplicate existing abilities

---

### 5. **Abilities Specialist**
**File:** `abilities.txt` (4,754 chars)
**Responsibility:** Generate physical abilities for non-caster classes
**Called:** Character creation, level-up (levels 2, 4, 6, 8, 10, 12, 14, 16, 18, 20)

**Output Schema:**
```swift
struct AbilityReward: Codable {
    var rewardType: String  // "ability"
    var name: String
    var effect: String      // Clear mechanical description
}
```

**Ability Types:**
- **OFFENSIVE** - Strike/Cleave/Backstab (damage, multi-target, crits, debuffs, DoT)
- **DEFENSIVE** - Shield Wall/Dodge/Endurance (block, evasion, damage reduction)
- **UTILITY** - Shadowstep/Tracker/Inspire (movement, detection, buffs, control)

**Class Specializations:**
- **Rogue:** Stealth, critical strikes, evasion, poison, lockpicking
- **Warrior:** Power attacks, shields, weapon mastery, intimidation
- **Ranger:** Tracking, ranged combat, animals, dual wielding
- **Monk:** Martial arts, ki, deflection, mobility, stunning
- **Bard:** Performance, inspiration, social skills, support
- **Barbarian:** Rage, endurance, primal instincts, brutal strikes

**Format Requirements:**
```
Power Strike: Deal +40% damage on your next attack. Type: Offensive
Iron Skin: Reduce incoming damage by 50% for 2 turns. Type: Defensive
```

**Context Provided:**
```
Char: L4 Rogue
Diff: normal
```

**Post-Generation Verification:**
- Check against existing abilities to avoid duplicates

---

### 6. **Spells Specialist**
**File:** `spells.txt` (868 chars)
**Responsibility:** Generate spells for Mage, Druid, Necromancer
**Called:** Character creation, level-up (caster classes only)

**Output Schema:**
```swift
struct SpellReward: Codable {
    var rewardType: String  // "spell"
    var name: String
    var effect: String
}
```

**Spell Schools:**

**Mage (Arcane):**
- Offensive: Fireball, Lightning Bolt, Ice Shard
- Control: Sleep, Slow, Confusion
- Utility: Detect Magic, Dispel, Teleport
- Defensive: Mage Armor, Shield, Stoneskin
- Summoning: Summon Elemental, Conjure Weapon
- Illusion: Invisibility, Mirror Image, Disguise

**Druid (Nature):**
- Animal: Speak with Animals, Animal Friendship, Beast Shape
- Plant: Entangle, Barkskin, Thorn Whip
- Weather: Call Lightning, Fog Cloud, Sleet Storm
- Healing: Cure Wounds, Goodberry, Regeneration
- Utility: Detect Poison, Purify Food, Pass without Trace

**Necromancer (Death):**
- Undead: Animate Dead, Summon Skeleton, Create Zombie
- Life Drain: Life Drain, Vampiric Touch, Death Coil
- Fear: Cause Fear, Horrifying Visage, Mind Freeze
- Curses: Ray of Enfeeblement, Curse of Weakness, Blight
- Death: Chill Touch, Necrotic Burst, Finger of Death

**Level Scaling:**
- Low (1-3): Basic effects, simple utility
- Mid (4-7): Area effects, stronger power
- High (8+): Powerful magic, complex effects

**Context Provided:**
```
Char: L6 Mage
Diff: normal
```

---

### 7. **Prayers Specialist**
**File:** `prayers.txt` (485 chars)
**Responsibility:** Generate divine prayers for Healer, Paladin
**Called:** Character creation, level-up (divine classes only)

**Output Schema:**
```swift
struct PrayerReward: Codable {
    var rewardType: String  // "prayer"
    var name: String
    var effect: String
}
```

**Prayer Types:**

**Healer:**
- Healing: Cure Wounds, Regeneration, Mass Healing
- Restoration: Remove Curse, Cure Disease, Restoration
- Protection: Bless, Protection from Evil, Divine Shield
- Support: Guidance, Aid, Divine Favor
- Resurrection: Revivify, Raise Dead

**Paladin:**
- Smiting: Smite Evil, Divine Smite, Holy Wrath
- Auras: Aura of Protection, Aura of Courage
- Healing: Lay on Hands, Divine Healing
- Holy Combat: Sacred Weapon, Holy Avenger
- Judgment: Detect Evil, Zone of Truth, Divine Judgment

**Context Provided:**
```
Char: L8 Healer
Diff: normal
```

---

### 8. **NPC Specialist**
**File:** `npc.txt` (3,146 chars)
**Responsibility:** Generate and manage persistent NPCs with dialogue
**Called:** Social encounters (first meeting or retrieval)

**Output Schema:**
```swift
struct NPCDefinition: Codable {
    var id: String          // Auto-generated UUID
    var name: String        // ONLY first/last name (NOT occupation)
    var occupation: String  // merchant, guard, innkeeper, etc.
    var appearance: String  // 1-2 sentences
    var personality: String // cheerful, grumpy, suspicious, etc.
    var relationshipStatus: String // neutral, friendly, hostile, allied
    var backstory: String   // 1-2 sentences
    var locationName: String
    var dialogue: String    // Context-aware conversation
    var mood: String        // happy, neutral, suspicious, angry, fearful, excited, sad
    var interactionCount: Int // Incremented each meeting
}
```

**Naming Rules (CRITICAL):**
- ✅ CORRECT: `name="Marigold"`, `occupation="Herbalist"`
- ❌ WRONG: `name="Marigold the Herbalist"`

**Persistence:**
- NPCs stored in `NPCRegistry`
- Retrieved by location on subsequent visits
- Interaction count tracked
- Relationship evolves based on player actions

**NPC Conversation Tracking:**
- `activeNPC` set when NPC introduced
- `activeNPCTurns` counts conversation length
- **Max 2 turns** unless player explicitly references NPC
- Cleared when combat encounter starts

**Dialogue Context Awareness:**
- First meeting (count=0): Introduction, establish role
- Repeated meeting (count>0): Reference past interactions
- Mood affects tone (happy=enthusiastic, angry=hostile)
- Location-specific knowledge

**Context Provided:**
```
Loc: Thornhaven Village
Diff: normal
NPC: Garrick (Blacksmith) - 3 previous interactions  // if retrieving existing
```

**Post-Generation Verification:**
- Check NPCRegistry for duplicate names
- Validate location assignment

---

## Turn Workflow

Every player action triggers this sequence:

### Phase 1: Pre-Turn Checks
```
1. Check if quest already completed → generate summary if needed
2. Check if quest failed (3 extra turns exceeded) → fail quest
3. Check if session needs reset (15 turns) → reset all sessions
```

### Phase 2: Encounter Generation
```
4. Check if continuing NPC conversation
   YES → Reuse activeNPC, increment activeNPCTurns
   NO  → Call Encounter specialist
```

### Phase 3: Entity Generation (Conditional)
```
5a. If encounter type = "combat":
    - Call MonsterAffixGenerator (CODE-BASED, no LLM)
    - Set pendingMonster (player must attack to start combat)
    - Clear activeNPC

5b. If encounter type = "social":
    - Check NPCRegistry for existing NPC at location
    - If found: retrieve and increment interactionCount
    - If not found: Call NPC specialist to generate
    - Set activeNPC, activeNPCTurns = 1

5c. If encounter type = "final":
    - Clear pendingMonster (non-combat quest completion)
    - Clear activeNPC
```

### Phase 4: Narrative Generation
```
6. Build context via ContextBuilder:
   - Character stats (compressed)
   - Location
   - Quest goal (or "NEW ADVENTURE" directive)
   - Recent quest types (if new adventure)
   - Encounter type + difficulty
   - Monster info (if combat) or NPC info (if social)
   - Recent actions (truncated)
   - Encounter history (compressed)

7. Add quest progression guidance via QuestProgressManager:
   - STAGE-EARLY / STAGE-MID / ⚠ FINAL ENC / ⚠ FINALE+N / ⚠ LAST CHANCE

8. Truncate prompt if > 600 chars (smart truncation preserves critical directives)

9. Call Adventure specialist → AdventureTurn

10. Sanitize narration:
    - Remove action suggestions
    - Validate monster names
    - Replace combat verbs
```

### Phase 5: Rewards & Progression (Code-Based)
```
11. Calculate rewards via RewardCalculator (CODE-BASED, no LLM):
    - XP: (10 + level*2) * difficulty multiplier
    - HP delta: combat=-1to-15, trap=level-scaled, other=+1 if below max
    - Gold: based on encounter type
    - Loot: shouldDropLoot boolean + itemDropCount

12. Generate loot if rewards.shouldDropLoot:
    - Call ItemAffixGenerator (CODE-BASED, no LLM)
    - Apply affixes from AffixDatabase (100 item affixes)
    - Track last 10 affixes to avoid repetition
```

### Phase 6: Apply State Changes
```
13. Update adventureProgress (currentEncounter++, encounterSummaries)
14. Check quest completion:
    - Retrieval: player action contains "take"/"claim" + artifact keyword
    - Combat: handled by combat system (boss defeat)
    - Other: LLM sets completed=true when objective met
15. Apply XP/HP/Gold (check for levelUp, check for death)
16. Handle loot (inventory management if > 20 items)
17. Store encounter summary (60 chars max)
18. Update suggestedActions
19. Append narrative to log
20. Save state
```

---

## Context Management

**Problem:** On-device LLM has ~2000 character context limit INCLUDING instruction files.

**Solution:** 3-tier context system via `ContextBuilder`

### Tier 1: Critical (Always Preserved)
- ⚠ markers (quest stage guidance)
- `stage-` (STAGE-EARLY, STAGE-MID)
- `action:` (player input)
- "NEW ADVENTURE" directive
- "AVOID QUEST TYPES" directive
- Encounter type (`enc:`)
- Monster/NPC info (if present)

### Tier 2: Contextual (If Space Allows)
- Quest goal (<120 chars)
- Location (<50 chars)
- Character stats (<80 chars)
- HP/gold (always kept, short)

### Tier 3: Dropped First
- Recent actions history
- Encounter count statistics
- Long descriptions

### Smart Truncation Algorithm
```swift
1. Extract all lines from prompt
2. Filter to mustKeep lines (Tier 1 + Tier 2)
3. If still > maxLength:
   - Split into priorityLines (Tier 1) and otherLines (Tier 2)
   - Keep all priorityLines
   - Add otherLines until hitting maxLength
4. Return truncated prompt
```

**Example Truncation:**
```
BEFORE (620 chars):
Char: Kael L5 Warrior HP:45 G:120
Loc: Dark Forest
Quest: Retrieve the stolen amulet from the bandit camp
Enc: exploration (normal)
Recent: searched clearing: found tracks leading north
Hist: 8 enc (3 combat, 2 social, 3 exploration)
NEW ADVENTURE - Generate new quest goal for this location
AVOID QUEST TYPES: retrieval, retrieval, retrieval
STAGE-MID: Advance 'Retrieve the stolen amulet'. Retrieval: show item/location. Combat: show boss/lair. Make progress.

AFTER (435 chars):
Loc: Dark Forest
Enc: exploration (normal)
NEW ADVENTURE - Generate new quest goal for this location
AVOID QUEST TYPES: retrieval, retrieval, retrieval
STAGE-MID: Advance 'Retrieve the stolen amulet'. Retrieval: show item/location. Combat: show boss/lair. Make progress.
```

---

## Code-Based Systems

These systems were originally planned as LLMs but replaced with deterministic code for reliability and context savings.

### 1. **RewardCalculator** (Replaces Progression LLM)
**File:** `RewardCalculator.swift`

**Formulas:**
- **XP:** `(10 + level*2) * difficultyMultiplier`
  - easy: 0.5x, normal: 1x, hard: 1.5x, boss: 2-3x
  - social: flat 2-5 XP (no formula)
  - final: 50-100 XP (quest completion bonus)
- **HP Delta:**
  - combat: -1 to -15 (scaled by difficulty)
  - boss: -8 to -20
  - trap: level-scaled (lv1-2: -1to-2, lv3-5: -2to-4, lv6-9: -3to-7, lv10+: -5to-10)
  - exploration/social/puzzle: +1 if below max, 0 if at max
- **Gold:**
  - combat: 5-50
  - treasure: 10-100
  - boss: 50-200
  - social: 0
- **Loot:**
  - combat/treasure: 0-1 items
  - boss: 1-2 items
  - social: 0

**Advantage:** Consistent, balanced, no LLM variance.

---

### 2. **ItemAffixGenerator** (Replaces Equipment LLM)
**File:** `ItemAffixGenerator.swift`
**Database:** `AffixDatabase.swift` (100 item affixes)

**Process:**
1. Determine rarity (difficulty-based probabilities)
2. Select base item type (Sword, Axe, Ring, etc.)
3. Apply affixes based on rarity:
   - Common: 20% chance for 1 affix
   - Uncommon: 50% chance for 1 affix
   - Rare: 70% chance for 2 affixes, else 1
   - Epic: 70% chance for 2 affixes, else 1 (always has affixes)
   - Legendary: Always 2 affixes (prefix + suffix)
4. Track last 10 affixes to avoid repetition
5. Check for duplicate names in inventory

**Affix Examples:**
- Prefixes: Flaming (+3 fire damage), Shadow (+2 stealth), Fortified (+4 defense)
- Suffixes: of the Bear (+3 STR), of Swiftness (+2 DEX), of Warding (+3 defense)

**Advantage:** No LLM hallucination, guaranteed mechanical effects, variety enforcement.

---

### 3. **MonsterAffixGenerator** (Replaces Monsters LLM)
**File:** `MonsterAffixGenerator.swift`
**Database:** `AffixDatabase.swift` (100 monster affixes), `MonsterDatabase.swift` (112 base monsters)

**Process:**
1. Filter 112 base monsters by character level (HP range matching)
2. Randomly select base monster
3. Scale base stats by character level
4. Determine affix count based on difficulty:
   - easy: 30% base + 5%/level (max 95%), 30% for 2 affixes at lv5+
   - normal: 50% base + 5%/level (max 95%), 50% for 2 affixes at lv5+
   - hard: 70% base + 5%/level (max 95%), 70% for 2 affixes at lv3+
   - boss: 100% chance, 2 affixes at lv3+
5. Apply affixes (prefix + suffix)
6. Track last 10 affixes to avoid repetition

**Monster Affix Examples:**
- Prefixes: Ancient (+50% HP), Frenzied (+dmg, -def), Elite (+all stats), Giant (+HP/size)
- Suffixes: of Shadows (stealth), the Eternal (regen), of Flame (fire damage), the Brutal (crit)

**Result:** "Ancient Goblin Shaman of Flame" (HP: 42, Damage: 9, Defense: 4, fire attacks)

**Advantage:** Balanced scaling, no LLM unreliability, variety enforcement.

---

### 4. **QuestValidator**
**File:** `QuestValidator.swift`

Infers quest type from `questGoal` keywords:
- `isCombatQuest()`: defeat, kill, destroy, stop, eliminate
- `isRetrievalQuest()`: find, retrieve, locate, discover
- `isEscortQuest()`: escort, protect, guide
- `isInvestigationQuest()`: investigate, solve, uncover
- `isRescueQuest()`: rescue, save, free
- `isDiplomaticQuest()`: negotiate, persuade, convince, diplomacy

Used to:
- Prevent LLM from prematurely marking combat quests complete (only code can mark complete via boss defeat)
- Detect retrieval quest completion (player action + narrative mention artifact acquisition)
- Track quest types for variety enforcement

---

## Session Management

**Problem:** LLM context accumulates conversation history, eventually exceeding limits.

**Solution:** `SpecialistSessionManager` with per-specialist and global resets.

### Session Lifecycle
```swift
// Initialize sessions
sessionManager = SpecialistSessionManager()

// Get session for specialist
let adventureSession = sessionManager.getSession(for: .adventure)

// Respond with session
let response = try await adventureSession.respond(to: prompt, generating: AdventureTurn.self)

// Track usage
sessionManager.recordUse(for: .adventure)
sessionManager.incrementTurnCount()

// Reset if needed
sessionManager.resetIfNeeded()  // Every 15 turns OR per-specialist limits
```

### Reset Triggers

**Global Reset (Every 15 Turns):**
- Clears ALL 8 specialist sessions
- Prevents unbounded history accumulation
- Ensures fresh context every ~2 adventures

**Per-Specialist Limits:**
- **Adventure:** 10 uses (maintains narrative coherence)
- **Equipment:** 3 uses (prevents affix repetition - NOW CODE-BASED)
- **Encounter:** 5 uses (variety enforcement)
- **Others:** 10 uses

**Reset Process:**
```swift
1. Destroy current LanguageModelSession instance
2. Create new session with systemInstructions
3. Reset usage counter to 0
```

---

## Narrative Sanitization

**Problem:** LLMs hallucinate combat resolution, suggest actions, invent wrong monsters.

**Solution:** Post-generation sanitization via `NarrativeProcessor`.

### 1. Combat Verb Removal
**Function:** `sanitizeNarration()` → `replaceCombatVerbs()`

**Forbidden Words:**
```swift
["defeat", "defeated", "kill", "killed", "slay", "slain", "strike", "struck",
 "smite", "smitten", "crush", "crushed", "stab", "stabbed", "shoot", "shot",
 "damage", "wound", "wounded"]
```

**Applied To:** `combat` and `final` encounters only

**Replacement:** All forbidden words → "confront"

**Reason:** Fighting happens in `CombatView`, narrative should only describe monster appearance.

---

### 2. Action Suggestion Removal
**Function:** `removeActionSuggestions()`

**Detected Patterns:**
```swift
// Modal verbs suggesting player actions
"you could", "you can", "you may", "you might"
"will you", "do you", "would you", "could you", "should you"
"what do you", "what will you", "how do you"
"perhaps you", "maybe you"

// Explicit choice markers
"you have the option", "you have a choice"
"options:", "choices:"

// Questions to player
Lines ending in "?" that contain "you" or start with "will", "do", "would", "what", "how"
```

**Action:** Remove entire line from narrative

**Reason:** Suggested actions belong in `suggestedActions` field, not narrative text.

---

### 3. Monster Name Validation
**Function:** `validateMonsterReferences()`

**Process:**
1. Extract expected monster name components (e.g., "Ancient Goblin Shaman" → ["ancient", "goblin", "shaman"])
2. Scan narrative for monster keywords (goblin, orc, skeleton, zombie, etc.)
3. If line mentions monster keyword BUT not the expected monster:
   - Replace with generic description: "You see something in the shadows." / "Movement ahead."
4. If line mentions correct monster: keep as-is

**Reason:** LLM sometimes invents different monsters than the one generated by MonsterAffixGenerator.

**Example:**
```
Expected: "Ancient Goblin Shaman"
Narrative: "A pack of rats scurries toward you."
Sanitized: "Movement ahead."
```

---

## Instruction File Compression

All instruction files compressed 50-80% to fit context limits.

**Compression Techniques:**
1. **Abbreviations:**
   - "Character:" → "Char:"
   - "Location:" → "Loc:"
   - "Encounter:" → "Enc:"
   - "Level" → "L" or "Lv"
   - "encounters" → "enc"

2. **Removed Words:**
   - Articles: "the", "a", "an"
   - Conjunctions: "and", "or", "but"
   - Redundant phrases: "in the context", "appears above"

3. **Bullet Points:**
   - Narrative explanations → short rules
   - Examples removed unless critical

4. **Symbols:**
   - "CRITICAL" → "⚠"
   - "✓ QUEST DONE" instead of "QUEST COMPLETED:"

**Compression Results:**
- adventure.txt: 359 chars (was 7,575 - 95% reduction)
- encounter.txt: 118 chars (was 1,885 - 94% reduction)
- progression.txt: 563 chars (was 4,310 - 87% reduction) - NOW CODE-BASED

---

## Summary

DunGen's LLM system achieves **high-quality narrative generation** within extreme **on-device constraints** through:

1. **Specialist Architecture** - 8 focused LLMs instead of 1 generalist
2. **Code-Based Determinism** - Progression/Equipment/Monsters handled by code
3. **Aggressive Compression** - Instructions reduced 50-80%, context truncated smartly
4. **Post-Generation Sanitization** - Remove hallucinations, validate outputs
5. **Session Management** - Reset every 15 turns to prevent context bloat
6. **Tiered Context** - Only send critical information to each specialist

**Result:** Consistent, engaging RPG gameplay powered by Apple's on-device LLMs with <2000 character total context budget.
