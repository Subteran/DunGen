# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DunGen is an iOS 26 fantasy RPG text adventure game that uses Apple's on-device LLM (FoundationModels framework) to generate immersive narratives, character interactions, and dynamic gameplay.

### Core Features
- **Permadeath rogue-like gameplay** with character history tracking
- **11 specialist LLMs** working together for coherent game experiences
- **16 character classes** across 8 races with racial stat modifiers
- **112 base monsters** (7 groups of 16) with procedural affix modifications
- **Sprite-based visualization** using 4×4 grid sprite sheets (256×384 per sprite, 1024×1536 total)
- **Dynamic combat system** with player-initiated combat and dedicated UI
- **Quest-based adventures** with clear objectives and progression tracking
- **Smart NPC system** with limited turn interactions (2 turns max unless explicitly referenced)
- **Equipment system** with prefix/suffix affixes and 20-slot inventory limit
- **Context window protection** through prompt size management and post-generation verification

### Key Mechanics
- **HP regeneration**: +1 HP per non-damaging encounter when below max
- **Encounter variety enforcement**: No consecutive combat, 3+ encounters between traps
- **Social encounter rewards**: 2-5 XP for meaningful conversations, no HP/gold rewards
- **Level-scaled trap damage**: 1-3 HP at level 1-2, scaling to 6-15 HP at level 10+
- **Affix variety system**: Tracks last 10 item/monster affixes to avoid repetition
- **Combat narration sanitization**: Removes combat resolution verbs from narrative (fighting only in combat system)

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
│   └── LevelingService.swift         # XP and leveling logic
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

### 11 Specialist LLMs

Each specialist has a focused responsibility to maintain coherent gameplay:

1. **World** - Generates fantasy worlds with 2-5 diverse starting locations
2. **Encounter** - Determines type (combat/social/exploration/puzzle/trap/stealth/chase/final) and difficulty
3. **Adventure** - Creates narrative text (EXACTLY 2-4 sentences) with quest progression
4. **Character** - Generates unique level 1 characters with 16 classes and 8 races
5. **Equipment** - Creates items using consistent prefix/suffix affix system
6. **Progression** - Calculates XP, HP, gold rewards; awards 2-5 XP for social encounters
7. **Abilities** - Generates physical abilities with mechanical effects
8. **Spells** - Creates arcane/nature/death/eldritch spells for caster classes
9. **Prayers** - Generates divine prayers for divine classes
10. **Monsters** - Modifies base monsters from 112-monster database with affixes
11. **NPC** - Creates and manages persistent NPCs with dialogue

**Key Design Principles:**
- Specialists work in sequence during `advanceScene()`
- Session resets every 15 turns via `SpecialistSessionManager`
- **Encounter variety enforcement** - no consecutive combat, 3+ between traps (code-enforced)
- **Combat narration sanitization** - removes combat resolution verbs (fighting only in combat system)
- **Narrative consistency** - Adventure LLM receives full adventure history as compressed summaries (~1200 chars max)
- **Post-generation verification** - locations, NPCs, abilities/spells checked for duplicates
- **Affix variety tracking** - last 10 item/monster affixes passed to Equipment/Monster LLMs

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

**Item Rarity and Affixes:**
- **Common/Uncommon/Rare**: Can be plain items (e.g., "Staff", "Sword") or have affixes
- **Epic/Legendary**: MUST have prefix and/or suffix affixes (validated at generation)
- **Affix Variety**: Tracks last 10 item affixes to avoid repetition
- **Generation Retry**: Max 3 attempts per item, graceful fallback on failure
- **Duplicate Prevention**: Checks existing inventory for duplicate item names

### Context Window Protection

**Critical safeguards to prevent prompt overflow:**

1. **Inventory Limit** - 20-slot maximum with UI-based management
2. **Location Cap** - Maximum 50 locations total
3. **User Input Truncation** - Player actions limited to 500 characters
4. **Action History Truncation** - Recent actions truncated to 200 characters each
5. **Post-Generation Verification** - Locations, NPCs, abilities/spells generated without full lists, then verified
6. **Session Resets** - Every 15 turns to clear conversation history
7. **Affix Tracking** - Only last 10 affixes sent to LLMs (not full history)
8. **Equipment Generation** - Max 3 retry attempts with error catching to prevent infinite loops

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
  - LogEntry system (supports character/monster sprites)

**CombatManager** (`Managers/CombatManager.swift`)
- Manages combat state: `inCombat`, `currentMonster`, `currentMonsterHP`, `pendingMonster`
- Player-initiated combat (monster pending until player attacks)
- Handles combat actions: attack, flee, surrender

**SpecialistSessionManager** (`Managers/SpecialistSessionManager.swift`)
- Manages 11 separate `LanguageModelSession` instances
- Resets sessions every 15 turns to prevent context overflow

## Game Flow

### Adventure Structure
- Each adventure: `questGoal`, `locationName`, `adventureStory`
- 7-12 encounters per adventure
- Progress tracked: `currentEncounter` / `totalEncounters`
- Stats tracked: XP gained, gold earned, monsters defeated

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
- Truncation (500 chars input, 200 chars history)
- Hard limits (20 inventory, 50 locations)
- Session resets (15 turns)
- Recent affixes only (last 10)

## State Management

**Character State:**
- `CharacterProfile` with racial modifiers applied
- HP, XP, gold, inventory (ItemDefinition with UUID)
- Abilities (physical), spells (arcane/nature/death/eldritch), prayers (divine)
- Name uniqueness enforced

**World State:**
- `WorldState` - world story + locations (max 50)
- `AdventureProgress` - includes `questGoal` and `encounterSummaries`
- `currentEnvironment` - specific location description

**Combat State:**
- `CombatManager.inCombat`, `pendingMonster`, `currentMonster`, `currentMonsterHP`

**Inventory State:**
- `detailedInventory` - max 20 items
- `needsInventoryManagement` - triggers overflow UI
- `pendingLoot` - items awaiting selection

## Testing

- Tests in `DunGenTests/` directory
- Swift Testing framework
- Mock implementations for protocols
- Integration tests for LLM behavior
- Level progression tests
- Character history tests
