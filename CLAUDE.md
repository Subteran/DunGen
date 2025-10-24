# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DunGen is an iOS 26 fantasy RPG text adventure game that uses Apple's on-device LLM (FoundationModels framework) to generate immersive narratives, character interactions, and dynamic gameplay.

### Core Features
- **Permadeath rogue-like gameplay** with character history tracking
- **10 specialist LLMs** (reduced from 11 - Progression eliminated via code)
- **16 character classes** across 8 races with racial stat modifiers
- **112 base monsters** (7 groups of 16) with procedural affix modifications
- **Sprite-based visualization** using 4×4 grid sprite sheets (256×384 per sprite, 1024×1536 total)
- **Dynamic combat system** with player-initiated combat and dedicated UI
- **6 quest types** with type-specific final encounter handling (retrieval, combat, escort, investigation, rescue, diplomatic)
- **Quest-based adventures** with clear objectives and progression tracking
- **Smart NPC system** with limited turn interactions (2 turns max unless explicitly referenced)
- **Equipment system** with prefix/suffix affixes and 20-slot inventory limit
- **Optimized context management** through tiered prompts, code-based calculations, and compressed instructions (50-80% reduction)

### Key Mechanics
- **Starting inventory**: 3 Healing Potions (2-5 HP) + 3 Bandages (1-3 HP) for survivability
- **HP regeneration**: +1 HP per non-damaging encounter when below max
- **Encounter variety enforcement**: No consecutive combat, 3+ encounters between traps
- **Social encounter rewards**: 2-5 XP for meaningful conversations, no HP/gold rewards
- **Level-scaled trap damage**: 1-2 HP at level 1-2, scaling to 5-10 HP at level 10+
- **Combat damage**: Monster attacks deal 2-8 HP damage
- **Affix variety system**: Tracks last 10 item/monster affixes to avoid repetition
- **Combat narration sanitization**: Removes combat resolution verbs from narrative (fighting only in combat system)
- **Quest completion validation**: Character must be alive to complete quests

## Build & Test Commands

```bash
# Build
xcodebuild -scheme DunGen -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build

# Run Tests
xcodebuild test -scheme DunGen -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'

# Run Single Test
xcodebuild test -scheme DunGen -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' -only-testing:DunGenTests/TestClassName/testMethodName
```

## Project Structure

```
DunGen/
├── DunGenApp.swift           # Main app entry point
├── LLM/
│   └── LLMGameEngine.swift   # Core game engine with context safeguards
├── Managers/
│   ├── CombatManager.swift           # Combat state with pending monster system
│   ├── AffixRegistry.swift           # Item/monster affix tracking (full history)
│   ├── NPCRegistry.swift             # NPC persistence
│   ├── SpecialistSessionManager.swift # LLM session management (resets every 15 turns)
│   ├── GameStatePersistence.swift    # Save/load system
│   ├── LevelingService.swift         # XP and leveling logic
│   ├── RewardCalculator.swift        # Code-based XP/gold/damage calculations
│   └── ContextBuilder.swift          # Tiered context generation per LLM
├── Models/
│   ├── WorldModels.swift         # AdventureType, WorldState, AdventureProgress, AdventureSummary
│   ├── CharacterModels.swift     # CharacterProfile, RaceModifiers, LevelReward
│   ├── MonsterModels.swift       # MonsterDefinition, MonsterAffix
│   ├── NPCModels.swift           # NPCDefinition, NPCDialogue
│   ├── ItemModels.swift          # ItemDefinition with UUID, ItemAffix
│   ├── EncounterModels.swift     # EncounterDetails, ProgressionRewards
│   ├── CharacterHistory.swift    # DeceasedCharacter (SwiftData), CharacterDeathReport
│   ├── MonsterDatabase.swift     # 112 base monsters
│   └── CharacterClass.swift      # 16 class definitions with grid positions
├── Views/
│   ├── GameView.swift            # Main narrative with loading overlay, sprite display
│   ├── CharacterView.swift       # Character stats display with sprite (270pt)
│   ├── CombatView.swift          # Dedicated combat interface
│   ├── DeathReportView.swift     # Final statistics on death
│   ├── CharacterHistoryView.swift # Fallen heroes list
│   ├── ItemDetailView.swift      # Equipment details
│   ├── InventoryManagementView.swift # 20-slot inventory manager
│   ├── WorldView.swift           # Location browser
│   ├── SpriteSheet.swift         # Sprite extraction (SpriteView, RaceClassSprite, MonsterSprite)
│   ├── PaperDollView.swift       # Character sprite display
│   ├── MailComposeView.swift     # Email composition for sharing/feedback
│   └── ContentView.swift         # Tab navigation
└── Resources/
    ├── L10n.swift                # Localization constants
    ├── art/                      # Sprite sheets (1024×1536, 4×4 grid)
    │   ├── {race}_sheet.png      # 8 race sheets (all implemented ✓)
    │   └── monsters_{one-seven}.png # 7 monster sheets (all implemented ✓)
    ├── LLMInstructions/          # Individual instruction files per specialist
    │   ├── abilities.txt         # Physical abilities specialist instructions
    │   ├── adventure.txt         # Adventure narrative specialist instructions
    │   ├── character.txt         # Character generation specialist instructions
    │   ├── encounter.txt         # Encounter type specialist instructions
    │   ├── equipment.txt         # Item generation specialist instructions
    │   ├── monsters.txt          # Monster modification specialist instructions
    │   ├── npc.txt               # NPC creation specialist instructions
    │   ├── prayers.txt           # Divine prayers specialist instructions
    │   ├── progression.txt       # XP/rewards specialist instructions
    │   ├── spells.txt            # Spells specialist instructions
    │   └── world.txt             # World generation specialist instructions
    └── en.lproj/
        └── Localizable.strings   # UI localization strings
```

## Architecture

### 10 Specialist LLMs

Each specialist has a focused responsibility to maintain coherent gameplay:

1. **World** - Generates fantasy worlds with 2-5 diverse starting locations
2. **Encounter** - Determines type (combat/social/exploration/puzzle/trap/stealth/chase/final) and difficulty
3. **Adventure** - Creates narrative text (EXACTLY 2-4 sentences) with quest progression
4. **Character** - Generates unique level 1 characters with 16 classes and 8 races
5. **Equipment** - Creates items using consistent prefix/suffix affix system with pre-determined rarity
6. **Abilities** - Generates physical abilities with mechanical effects
7. **Spells** - Creates arcane/nature/death/eldritch spells for caster classes
8. **Prayers** - Generates divine prayers for divine classes
9. **Monsters** - Modifies base monsters from 112-monster database with affixes
10. **NPC** - Creates and manages persistent NPCs with dialogue

**Note**: Progression LLM was eliminated - XP/gold/damage/loot now calculated via `RewardCalculator` using deterministic formulas.

**Key Design Principles:**
- Specialists work in sequence during `advanceScene()`
- Session resets: Every 15 turns via `SpecialistSessionManager` (Adventure: 10 uses, Equipment: 3 uses, Encounter: 5 uses)
- **Tiered context system** - Each LLM receives minimal relevant context via `ContextBuilder`
- **Code-based rewards** - XP/gold/damage calculated by `RewardCalculator`, no LLM variance
- **Encounter variety enforcement** - no consecutive combat, 3+ between traps (code-enforced via count tracking)
- **Combat narration sanitization** - removes combat resolution verbs (fighting only in combat system)
- **Narrative consistency** - Adventure LLM receives last 2 encounter summaries (60 chars each)
- **Post-generation verification** - locations, NPCs, abilities/spells checked for duplicates
- **Affix variety tracking** - last 10 item/monster affixes passed to Equipment/Monster LLMs
- **Adventure state cleanup** - pending monsters/NPCs/traps cleared on adventure start/completion
- **Compressed instructions** - All instruction files reduced by 50-80% using bullet points and abbreviations

### Character System

**16 Classes (4×4 grid):**
- Row 0: Rogue, Warrior, Mage, Healer
- Row 1: Paladin, Ranger, Monk, Bard
- Row 2: Druid, Necromancer, Barbarian, Warlock
- Row 3: Sorcerer, Cleric, Assassin, Berserker

**8 Races with Stat Modifiers:**
- **Human**: No modifiers (balanced)
- **Elf**: +2 DEX, +1 INT, +1 WIS, +1 CHA, -1 STR, -1 CON
- **Dwarf**: +2 CON, +1 STR, +1 WIS, -1 DEX, -1 CHA
- **Halfling**: +2 DEX, +1 WIS, +1 CHA, -2 STR
- **Half-Elf**: +2 CHA, +1 DEX
- **Half-Orc**: +2 STR, +1 CON, -1 INT, -1 CHA
- **Gnome**: +2 INT, +1 DEX, +1 CON, -1 STR
- **Ursa**: +2 STR, +2 CON, +1 WIS, -1 DEX, -1 INT

**Sprite System:**
- Each race/monster group has a 4×4 sprite sheet (1024×1536, 256×384 per sprite)
- `RaceClassSprite` extracts sprite based on race + class
- `MonsterSprite` extracts sprite based on monster's database position
- Character sprites: `{race}_sheet.png` (e.g., `dwarf_sheet.png`)
- Monster sprites: `monsters_one.png` through `monsters_seven.png`
- `CharacterClass.gridPosition` maps each class to grid coordinates
- All 8 race sheets + 7 monster sheets implemented ✓

### Equipment System

**Item Generation Strategy:**
- **Reduced Loot Frequency**: Max 1 item per encounter (1-2 for final boss encounters only)
- **Pre-determined Rarity**: Rarity determined before LLM generation to reduce failures
  - Normal/Easy: 1% legendary, 5% epic, 10% rare, 30% uncommon, 54% common
  - Hard: 2% legendary, 8% epic, 15% rare, 30% uncommon, 45% common
  - Boss: 5% legendary, 15% epic, 25% rare, 30% uncommon, 25% common
- **Common/Uncommon/Rare**: Can be plain items (e.g., "Staff", "Sword") or have affixes
- **Epic/Legendary**: MUST have prefix and/or suffix affixes (validated at generation)
- **Affix Variety**: Tracks last 10 item affixes to avoid repetition
- **Generation Retry**: Max 3 attempts per item, graceful fallback on failure
- **Duplicate Prevention**: Checks existing inventory for duplicate item names
- **Rarity Enforcement**: If LLM generates wrong rarity, it's corrected to match pre-determined value

### Context Window Protection

**CRITICAL: Apple's on-device LLM has a ~2000 character context window INCLUDING instruction files**

**Safeguards to prevent prompt overflow:**

1. **Instruction File Compression** - Aggressively reduced specialist instructions:
   - Adventure: 359 chars (was 7,575 - 95% reduction)
   - Encounter: 340 chars (was 1,885 - 82% reduction)
   - Progression: 563 chars (was 4,310 - 87% reduction)
2. **Dynamic Prompt Truncation** - Max 500 characters (ultra-aggressive truncation preserves only critical info)
3. **Total Prompt Size** - Worst case: 500 (dynamic) + 359 (instructions) = 859 chars (well within limit)
4. **Inventory Limit** - 20-slot maximum with UI-based management
5. **Location Cap** - Maximum 50 locations total
6. **User Input Truncation** - Player actions limited to 500 characters
7. **Action History Truncation** - Recent actions truncated to 200 characters each
8. **Post-Generation Verification** - Locations, NPCs, abilities/spells generated without full lists, then verified
9. **Session Resets** - Every 15 turns to clear conversation history
10. **Affix Tracking** - Only last 10 affixes sent to LLMs (not full history)
11. **Equipment Generation** - Max 3 retry attempts with error catching to prevent infinite loops

### Core Components

**LLMGameEngine** (`LLM/LLMGameEngine.swift`)
- Main game orchestrator using Apple's FoundationModels
- `@MainActor` and `@Observable` for SwiftUI integration
- Uses `@Generable` and `@Guide` macros for structured LLM output
- Delegates to specialized managers (CombatManager, NPCRegistry, AffixRegistry)
- Coordinates 11 specialist LLMs
- Key features:
  - `isGenerating` flag for loading overlay
  - `knownItemAffixes`/`knownMonsterAffixes` Sets (last 10 affixes)
  - Encounter variety enforcement (code-based)
  - Combat narration sanitization
  - Social encounter reward handling (2-5 XP only)
  - NPC conversation tracking (`activeNPC`, `activeNPCTurns`)
  - Trap handling (`pendingTrap` with avoidance mechanics)
  - LogEntry system (supports character/monster sprites)

**CombatManager** (`Managers/CombatManager.swift`)
- Manages combat state: `inCombat`, `currentMonster`, `currentMonsterHP`, `pendingMonster`
- `currentMonsterHP` tracks monster's current HP separately from base `monster.hp`
- Player-initiated combat (monster pending until player attacks)
- Handles combat actions: attack, flee, surrender
- Initiative system: 70% chance player strikes first
- Monster damage: 2-8 HP per attack

**SpecialistSessionManager** (`Managers/SpecialistSessionManager.swift`)
- Manages 11 separate `LanguageModelSession` instances
- Global reset: Every 15 turns to clear all session history
- Per-specialist usage limits (auto-reset when reached):
  - Adventure specialist: 10 uses (maintains narrative coherence)
  - Equipment specialist: 3 uses (prevents affix repetition)
  - Encounter specialist: 5 uses (variety enforcement)
  - Other specialists: 10 uses

## Game Flow

### Adventure Structure
- Each adventure: `questGoal`, `locationName`, `adventureStory`
- 7-12 encounters per adventure
- Progress tracked: `currentEncounter` / `totalEncounters`
- Stats tracked: XP gained, gold earned, monsters defeated

### Quest Types
Quest type is inferred from keywords in the `questGoal` text. Each type has specific final encounter handling:

1. **Retrieval Quests** (find, retrieve, locate, discover)
   - Final encounter: "final" type (non-combat)
   - Completion: Present artifact/item, mark completed=true when player takes it
   - Example: "Find the lost amulet" → Present amulet → Player "Take the amulet" → Quest complete

2. **Combat Quests** (defeat, kill, destroy, stop)
   - Final encounter: "combat" type with "boss" difficulty
   - Completion: Boss monster generated, mark completed=true when combat won
   - Example: "Defeat the goblin warlord" → Boss fight → Player wins → Quest complete

3. **Escort Quests** (escort, protect, guide)
   - Final encounter: "final" type OR "combat" type (hard difficulty) if threat
   - Completion: Present destination or final threat, mark completed=true when reached/defeated
   - Example: "Escort the merchant to the village" → Arrive safely OR defeat ambushers → Quest complete

4. **Investigation Quests** (investigate, solve, uncover)
   - Final encounter: "final" type (non-combat)
   - Completion: Reveal solution/truth, mark completed=true when player acknowledges
   - Example: "Investigate the mysterious murders" → Reveal culprit → Player "Confront the mayor" → Quest complete

5. **Rescue Quests** (rescue, save, free)
   - Final encounter: "combat" type (hard difficulty) OR "final" type depending on scenario
   - Completion: Present captive/prisoner, mark completed=true when freed (combat win or unlock)
   - Example: "Rescue the kidnapped child" → Defeat captor OR pick lock → Quest complete

6. **Diplomatic Quests** (negotiate, persuade, convince, diplomacy)
   - Final encounter: "social" type (critical negotiation)
   - Completion: Present key NPC, mark completed=true when agreement reached
   - Example: "Negotiate peace between the clans" → Meet chieftain → Player persuades → Quest complete

### Turn Loop
1. Player selects action → `submitPlayer(input:)` (truncated to 500 chars)
2. `isGenerating = true` triggers loading overlay
3. `advanceScene()` orchestrates specialists:
   - Encounter LLM determines type/difficulty (variety enforced in code)
   - Monster LLM generates pending monster (if combat) with affix variety
   - NPC LLM generates/retrieves NPC (if social) with duplicate verification
   - Adventure LLM creates narrative (2-4 sentences, sanitized)
   - Progression LLM calculates rewards (social: 2-5 XP only)
   - Equipment LLM generates loot (if dropped) with affix variety
4. `apply()` updates game state, triggers inventory management if needed
5. `saveState()` persists progress
6. `isGenerating = false` dismisses loading overlay

### Combat Flow
1. Monster encounter → `pendingMonster` set, monster stats displayed
2. Player attacks → `CombatManager.enterCombat()`
3. `GameView` shows `CombatView`
4. Combat actions → damage calculated, death checked
5. Victory/defeat handled

### Trap Flow
1. Trap encounter → `pendingTrap` set with damage amount
2. Player presented with avoidance choices: "Attempt to disarm", "Carefully proceed", "Try to avoid"
3. Player responds:
   - **Attempted avoidance** (keywords: disarm, avoid, careful, dodge, jump, step, roll, evade):
     - 50% chance to avoid completely (no damage)
     - 50% chance to take half damage (minimum 1 HP)
   - **No avoidance attempt**: Take full trap damage
4. Death checked, next encounter triggered

### Reward System
**XP/gold for:**
- Combat victories
- Treasure finding (non-empty containers)
- Challenge success (puzzles, obstacles)
- Boss defeats
- Social encounters (2-5 XP only, no gold/HP)

**No HP/gold for:** social encounters, exploration, failed attempts, stealth, chases

## Important Implementation Details

### Narrative Consistency System

**Three-tier approach:**

1. **Encounter Summary Tracking**
   - `AdventureProgress.encounterSummaries` stores one-sentence summaries (~100 chars each)
   - Max 12 summaries per adventure = ~1200 characters total

2. **Full Adventure History Context**
   - `buildAdventureHistory()` joins summaries with " → " separator
   - Passed to Adventure LLM in every turn
   - Enables reference to past events, avoids repetition

3. **Strict Length Enforcement**
   - Adventure LLM constrained to EXACTLY 2-4 sentences
   - Prevents rambling, forces focus on key details

### Post-Generation Verification Pattern

Used for locations, NPCs, abilities/spells:

1. Initial generation - no existing items listed in prompt
2. Check for duplicates - compare against Set
3. If duplicate - regenerate with explicit exclusion (only list duplicates, not full history)
4. Max 5-10 attempts before fallback

### Prompt Size Strategy

**Never send:**
- Full location lists
- Full NPC lists
- Full abilities/spells lists
- Unbounded user input
- Unbounded action history

**Always use:**
- Post-generation verification
- Ultra-aggressive truncation (500 chars max, preserves only critical instructions)
- Truncation (500 chars input, 200 chars history)
- Hard limits (20 inventory, 50 locations)
- Session resets (15 turns)
- Recent affixes only (last 10)

**Smart Truncation Strategy:**
- Max prompt length: 500 characters (reduced to fit within model's strict context limit)
- Preserves ONLY: "CRITICAL", "QUEST STAGE", short "quest:", "location:", "encounter:" lines
- Drops ALL: character stats, history, monster details, abilities, recent actions
- Final fallback: preserve last 350 chars (critical instructions only)
- Ensures quest completion and combat instructions never get cut off

## State Management

All game state is persisted to JSON file (`gameState.json`) for save/load continuity.

### Persisted State Categories

**Character State:**
- `CharacterProfile` with racial modifiers applied
- HP, XP, gold, inventory (ItemDefinition with UUID for unique identification)
- Starting inventory: 3 Healing Potions + 3 Bandages
- Abilities (physical), spells (arcane/nature/death/eldritch), prayers (divine)
- Name uniqueness enforced
- Character creation flow: `awaitingCustomCharacterName`, `partialCharacter`, `awaitingWorldContinue`

**World State:**
- `WorldState` - world story + locations (max 50)
- `AdventureProgress` - includes `questGoal` and `encounterSummaries`
- `currentLocation` - current adventure type
- `currentEnvironment` - specific location description

**Combat State:**
- `inCombat` - whether combat is active
- `currentMonster` - monster being fought
- `currentMonsterHP` - current HP of monster in combat
- `pendingMonster` - monster awaiting player attack decision

**Trap State:**
- `pendingTrap` - stores damage and narrative until player responds

**Inventory State:**
- `detailedInventory` - current items (max 20)
- `needsInventoryManagement` - triggers overflow UI
- `pendingLoot` - items awaiting inventory selection

**Trading State:**
- `pendingTransaction` - NPC purchase offers (items, cost, NPC)

**NPC State:**
- `activeNPC` - current NPC in conversation
- `activeNPCTurns` - conversation turn counter (max 2)

**Adventure Tracking:**
- `currentAdventureXP` - XP earned in current adventure
- `currentAdventureGold` - gold earned in current adventure
- `currentAdventureMonsters` - monsters defeated in current adventure
- `adventureSummary` - summary of completed adventure
- `showingAdventureSummary` - UI state for summary display

**Statistics:**
- `gameStartTime` - when character was created
- `adventuresCompleted` - total adventures completed
- `itemsCollected` - total items collected

**Encounter Tracking:**
- `recentEncounterTypes` - last 5 encounter types for variety enforcement

**UI State:**
- `log` - full narrative log with sprites
- `suggestedActions` - current action choices
- `awaitingLocationSelection` - location selection UI state

### Not Persisted (Transient/Runtime)
- `isGenerating` - loading state
- `lastPrompt` - debug info
- `availability` - LLM availability check
- `sessionManager` - rebuilt on load
- `knownItemAffixes` / `knownMonsterAffixes` - tracked in AffixRegistry
- `characterDied` / `deathReport` - death flow handled separately

## Testing

- Tests in `DunGenTests/` directory
- Swift Testing framework
- Mock implementations for protocols
- Integration tests for LLM behavior
- Level progression tests
- Character history tests
