# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DunGen is an iOS 26 fantasy RPG text adventure game that uses Apple's on-device LLM (FoundationModels framework) to generate immersive narratives, character interactions, and dynamic gameplay.

### Core Features
- **Permadeath rogue-like gameplay** with character history tracking
- **8 specialist LLMs** (reduced from 11 - Progression/Equipment/Monsters eliminated via code)
- **16 character classes** across 8 races with racial stat modifiers
- **112 base monsters** (7 groups of 16) with **deterministic affix system** (100 prefixes/suffixes)
- **Sprite-based visualization** using 4×4 grid sprite sheets (256×384 per sprite, 1024×1536 total)
- **Dynamic combat system** with player-initiated combat and dedicated UI
- **6 quest types** with type-specific final encounter handling (retrieval, combat, escort, investigation, rescue, diplomatic)
- **Quest-based adventures** with clear objectives and progression tracking
- **Smart NPC system** with limited turn interactions (2 turns max unless explicitly referenced)
- **Deterministic equipment system** with 100 item prefixes/suffixes (no LLM generation)
- **Optimized context management** through tiered prompts, code-based calculations, and compressed instructions (50-80% reduction)

### Key Mechanics
- **Starting inventory**: 3 Healing Potions (2-5 HP) + 3 Bandages (1-3 HP) for survivability (displayed as stacked items with quantity)
- **HP regeneration**: +1 HP per non-damaging encounter when below max
- **Encounter variety enforcement**: No consecutive combat, 3+ encounters between traps
- **Quest variety enforcement**: Tracks last 5 completed quest types (combat, retrieval, escort, investigation, rescue, diplomatic), passes to Adventure LLM to avoid repetition
- **Social encounter rewards**: 2-5 XP for meaningful conversations, no HP/gold rewards
- **Level-scaled trap damage**: 1-2 HP at level 1-2, scaling to 5-10 HP at level 10+
- **Combat damage**: Monster attacks deal 2-8 HP damage
- **Affix variety system**: Tracks last 10 item/monster affixes to avoid repetition
- **Combat narration sanitization**: Removes combat resolution verbs from narrative (fighting only in combat system)
- **Combat encounter isolation**: Item purchases/acquisitions blocked during combat to prevent UI conflicts
- **Quest completion validation**: Character must be alive to complete quests
- **Code-controlled quest completion**: Combat and retrieval quests can only be marked complete by code (boss defeat or artifact taken), not by LLM

## Build & Test Commands

**IMPORTANT**: Use `platform=iOS,name=Momo` for ALL tests (Momo is an iPad Pro 11" M5 with iOS 26.0.1 and on-device LLM support)

**Known Issue**: Apple's FoundationModels framework has intermittent "Unsupported language pl" bugs that cause random test failures - prompt sanitization added to mitigate

```bash
# Build
xcodebuild -scheme DunGen -destination 'platform=iOS,name=Momo' build

# Run ALL Tests
xcodebuild test -scheme DunGen -destination 'platform=iOS,name=Momo'

# Run LLM Integration Tests
xcodebuild test -scheme DunGen -destination 'platform=iOS,name=Momo' -only-testing:DunGenTests/FullAdventureIntegrationTest

# Run Single Test
xcodebuild test -scheme DunGen -destination 'platform=iOS,name=Momo' -only-testing:DunGenTests/TestClassName/testMethodName

# Check LLM Availability (diagnostic)
xcodebuild test -scheme DunGen -destination 'platform=iOS,name=Momo' -only-testing:DunGenTests/LLMAvailabilityTest
```

## Project Structure

```
DunGen/
├── DunGenApp.swift           # Main app entry point
├── LLM/
│   └── LLMGameEngine.swift   # Core game engine with context safeguards
├── Managers/
│   ├── CombatManager.swift           # Combat state with pending monster system
│   ├── AffixRegistry.swift           # Item/monster affix tracking (last 10 prefixes/suffixes)
│   ├── AffixDatabase.swift           # 100 monster + 100 item affixes with stats
│   ├── MonsterAffixGenerator.swift   # Deterministic monster affix application
│   ├── ItemAffixGenerator.swift      # Deterministic item generation
│   ├── MonsterGenerator.swift        # Monster selection + affix application
│   ├── LootGenerator.swift           # Item type/rarity + affix application
│   ├── NPCRegistry.swift             # NPC persistence
│   ├── SpecialistSessionManager.swift # LLM session management with token tracking
│   ├── GameStatePersistence.swift    # Save/load system
│   ├── LevelingService.swift         # XP and leveling logic
│   ├── RewardCalculator.swift        # Code-based XP/gold/damage calculations
│   ├── ContextBuilder.swift          # Tiered context generation per LLM with quest progression
│   ├── QuestProgressManager.swift    # Quest stage guidance and completion logic
│   └── NarrativeProcessor.swift      # Narrative sanitization and smart truncation
├── Utilities/
│   └── TokenEstimator.swift          # Token estimation and context usage analysis
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

### 8 Specialist LLMs (Down from 11)

Each specialist has a focused responsibility to maintain coherent gameplay:

1. **World** - Generates fantasy worlds with 2-5 diverse starting locations
2. **Encounter** - Determines type (combat/social/exploration/puzzle/trap/stealth/chase/final) and difficulty
3. **Adventure** - Creates narrative text (EXACTLY 2-4 sentences) with quest progression
4. **Character** - Generates unique level 1 characters with 16 classes and 8 races
5. **Abilities** - Generates physical abilities with mechanical effects
6. **Spells** - Creates arcane/nature/death/eldritch spells for caster classes
7. **Prayers** - Generates divine prayers for divine classes
8. **NPC** - Creates and manages persistent NPCs with dialogue

**Eliminated LLMs (Now Code-Based):**
- **Progression** - XP/gold/damage/loot calculated via `RewardCalculator` using deterministic formulas
- **Equipment** - Items generated via `ItemAffixGenerator` using 100 prefixes/suffixes from `AffixDatabase`
- **Monsters** - Affixes applied via `MonsterAffixGenerator` using 100 prefixes/suffixes from `AffixDatabase`

**Key Design Principles:**
- Specialists work in sequence during `advanceScene()`
- Session resets: Per-specialist via `SpecialistSessionManager` (Adventure: 8 uses, Equipment: 10 uses, Encounter: 15 uses, Monsters/NPC: 15 uses, Others: 20 uses)
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

### Monster System (Deterministic Affixes - No LLM)

**Monster Generation Strategy:**
- **Base Monsters**: 112 monsters from `MonsterDatabase` (7 groups of 16)
- **Level-Based Selection**: Filters by HP range based on character level
  - Level 1-3: HP ≤ 20
  - Level 4-7: HP 16-60
  - Level 8-12: HP 46-120
  - Level 13+: HP > 80
- **Combat Quest Boss Matching**: Boss monsters guaranteed to match quest goals
  - During world generation, combat quests pre-generate a **base monster name** (e.g., "Skeleton")
  - Quest goal updated to include specific boss (e.g., "Defeat the Skeleton" instead of "Defeat the necromancer")
  - Base monster name stored in `WorldLocation.bossMonsterName`
  - Final boss encounter generates the exact base monster (may have affixes like "Ancient Skeleton")
  - `MonsterDefinition.baseName` preserves base name even with affixes applied
  - Ensures quest objectives always match available monsters regardless of affixes
- **Affix Application Rules**:
  - Easy: 30% base chance + 5% per level (max 95%)
  - Normal: 50% base chance + 5% per level (max 95%)
  - Hard: 70% base chance + 5% per level (max 95%)
  - Boss: 100% chance (always affixed)
- **Affix Count**:
  - Easy: 1 affix (30% chance for 2 at level 5+)
  - Normal: 1 affix (50% chance for 2 at level 5+)
  - Hard: 1 affix (70% chance for 2 at level 3+)
  - Boss: 2 affixes at level 3+, else 1
- **100 Monster Affixes** (50 prefixes + 50 suffixes):
  - HP multipliers: 1.0x to 2.0x
  - Damage bonuses: +1 to +7
  - Defense bonuses: +1 to +6
  - Special effects: poison, fire, ice, lifesteal, reflect, etc.
- **Affix Variety**: Tracks last 10 prefixes and 10 suffixes separately
- **Stat Scaling**: Base HP/defense scaled by character level before affixes applied

### Equipment System (Fully Deterministic - No LLM)

**Item Generation Strategy:**
- **Reduced Loot Frequency**: Max 1 item per encounter (1-2 for final boss encounters only)
- **Pre-determined Rarity**: Rarity determined by difficulty
  - Normal/Easy: 1% legendary, 5% epic, 10% rare, 30% uncommon, 54% common
  - Hard: 2% legendary, 8% epic, 15% rare, 30% uncommon, 45% common
  - Boss: 5% legendary, 15% epic, 25% rare, 30% uncommon, 25% common
- **Affix Application Rules**:
  - Common: 20% chance for 1 affix
  - Uncommon: 50% chance for 1 affix
  - Rare: 70% chance for 2 affixes, else 1
  - Epic: 70% chance for 2 affixes, else 1 (always has affixes)
  - Legendary: Always 2 affixes (prefix + suffix)
- **100 Item Affixes** (50 prefixes + 50 suffixes):
  - Damage bonuses: +1 to +7
  - Defense bonuses: +1 to +5
  - Elemental effects: fire, ice, lightning, poison, holy, void, etc.
  - Special properties: lifesteal, armor pierce, speed, accuracy
- **Affix Variety**: Tracks last 10 prefixes and 10 suffixes separately
- **Base Item Types**: Weapons (Sword, Axe, Mace, Dagger, Spear, Bow, Staff, Wand), Armor (Chestplate, Helmet, Gauntlets, Boots, Shield, Cloak, Bracers), Accessories (Ring, Amulet, Belt, Talisman, Pendant, Brooch)
- **Duplicate Prevention**: Checks existing inventory for duplicate item names

### Context Window Management

**Apple's on-device LLM context window: 4096 TOKENS (per TN3193)**

**Token Budget Allocation:**
- Total: 4096 tokens
- Conversion: 1 token ≈ 4 characters
- Budget breakdown per turn:
  - System instructions: ~90 tokens (static)
  - Conversation history: grows with each exchange (past prompts + responses)
  - Current prompt: dynamic (calculated)
  - Upcoming response: ~200 tokens (reserved)
  - Safety margin: 50 tokens

**Example Calculation (Adventure LLM, Turn 5):**
```
Total budget:          4096 tokens
- Instructions:         -234 tokens (936 chars)
- History (4 exchanges): -1136 tokens (4544 chars: 4 prompts ~600 chars + 4 responses ~536 chars)
- Response buffer:      -200 tokens (800 chars, strictly enforced)
- Safety margin:         -50 tokens
= Available for prompt: 2476 tokens ≈ 9,904 chars

As history grows, available prompt space shrinks:
Turn 1: ~3600 tokens available
Turn 4: ~2850 tokens available
Turn 6: Session reset triggered (6 uses ≈ 3400 tokens used)

With 6-9 encounters per adventure, session resets mid-quest are expected.

⚠️ Response length must be strictly enforced - observed responses reached 425 tokens
without constraints, exceeding the 200 token budget and risking context overflow.
```

**Per-Specialist Limits:**

| Specialist | Reset After | Tokens/Exchange | Prompt Limit |
|------------|-------------|-----------------|--------------|
| Adventure | 6 uses | ~568 | Dynamic (calc) |
| Encounter | 15 uses | ~253 | 1000 chars |
| Monster | 15 uses | ~253 | 1000 chars |
| NPC | 15 uses | ~253 | 1000 chars |
| Equipment | 10 uses | ~380 | 1500 chars |
| Others | 20 uses | ~190 | 750 chars |

**Context Management Strategies:**

1. **Instruction File Compression** - Aggressively reduced specialist instructions:
   - Adventure: 936 chars (~234 tokens, was 7,575 - 97% reduction)
   - Encounter: 340 chars (~85 tokens, was 1,885 - 82% reduction)
   - Progression: 563 chars (~140 tokens, was 4,310 - 87% reduction)
2. **Strict Response Length Enforcement** - Adventure LLM constrained to prevent token overflow:
   - **⚠️ NARRATIVE LENGTH**: 2-4 SHORT sentences ONLY (max 400 chars)
   - Explicit "Stop after 4 sentences. NO extra paragraphs" instruction
   - JSON output format reminder to prevent extra text in response
   - Observed: Some responses reach ~425 tokens without strict constraints
3. **Dynamic Prompt Sizing** - Adventure LLM uses `TokenEstimator` to calculate max safe prompt size based on:
   - Instruction size (~769 chars = ~192 tokens)
   - Conversation history (all past prompts + responses from transcript)
   - Response buffer (800 chars = ~200 tokens for upcoming response)
   - Safety margin (50 tokens)
   - Formula: `available_for_current_prompt = 4096 - instructions - history - upcoming_response - margin`
   - Logs detailed token budget breakdown each turn
4. **Integrated Quest Progression** - Quest guidance built into `ContextBuilder` instead of appended after (prevents truncation)
5. **Critical Instructions in System Prompt** - Moved monster/combat rules from per-prompt to adventure.txt (saves ~100 chars per prompt)
6. **Token Estimation Utility** - `TokenEstimator` provides:
   - Token count estimation (chars ÷ 4)
   - Context usage analysis with warnings
   - Max safe prompt size calculation
   - Remaining token tracking
6. **Session-Aware Resets** - Each specialist resets based on token budget:
   - Adventure: 9 uses (was 8, recalculated with new system)
   - Equipment: 10 uses
   - Encounter/Monster/NPC: 15 uses
   - Others: 20 uses
7. **Enhanced Transcript Metrics** - `SpecialistSessionManager` logs:
   - Token estimates for prompts/responses
   - Total token usage (X/4096)
   - Percentage used with warnings at 75%/85%/95%
   - Response size tracking
8. **Smart Prompt Truncation** - `NarrativeProcessor.smartTruncatePrompt()` prioritizes:
   - Critical instructions (⚠️ markers, STAGE-, NEW ADVENTURE)
   - Quest variety (AVOID QUEST TYPES)
   - Player action and encounter type
   - Character/monster/NPC info
   - Drops: action history, encounter statistics
9. **GenerationOptions per Specialist** - Fine-tuned temperature:
   - Adventure: temp 0.9 (creative storytelling)
   - Encounter: temp 0.6 (balanced variety)
   - Monster/NPC: temp 0.5 (consistent but varied)
   - Equipment: temp 0.4 (mechanical consistency)
   - World/Character: temp 0.8 (creative world-building)
   - Abilities/Spells/Prayers: temp 0.5 (balanced mechanics + flavor)
   - Progression: temp 0.3 (deterministic calculations)
10. **Inventory Limit** - 20-slot maximum with UI-based management
11. **Location Cap** - Maximum 50 locations total
12. **User Input Truncation** - Player actions limited to 500 characters
13. **Action History Truncation** - Recent actions truncated to 200 characters each
14. **Post-Generation Verification** - Locations, NPCs, abilities/spells generated without full lists, then verified
15. **Global Session Reset** - Every 15 turns to clear all conversation history (backup safeguard)
16. **Affix Tracking** - Only last 10 affixes sent to LLMs (not full history)

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
- Manages 8 separate `LanguageModelSession` instances
- Global reset: Every 15 turns to clear all session history (backup safeguard)
- Per-specialist usage limits (token-budget aware, auto-reset when reached):
  - Adventure: 12 uses (~316 tokens/exchange)
  - Encounter: 15 uses (~253 tokens/exchange)
  - Monster/NPC: 15 uses (~253 tokens/exchange)
  - Equipment: 10 uses (~380 tokens/exchange)
  - Others: 20 uses (~190 tokens/exchange)
- Transcript logging for debugging and metrics
- Token usage warnings when approaching 4096 limit

## Game Flow

### Adventure Structure
- Each adventure: `questGoal`, `locationName`, `adventureStory`
- 6-9 encounters per adventure
- Progress tracked: `currentEncounter` / `totalEncounters`
- Stats tracked: XP gained, gold earned, monsters defeated

### Quest Progression Stages

Quest pacing is controlled by `QuestProgressManager` based on encounter progress:

**Stage Thresholds (for 6-9 encounter quests):**
- **Early (< 50%)**: Encounters 1-2 (6-enc) or 1-4 (9-enc)
  - Guidance: "Intro clues/NPCs/hints. Show obstacles, NO artifact yet."
  - Purpose: Establish quest, build atmosphere, introduce challenges

- **Mid (50-84%)**: Encounters 3-4 (6-enc) or 5-7 (9-enc)
  - Guidance: "Hint at item location. Build tension."
  - Purpose: Show progress, provide clues about objective location

- **Late (85-99%)**: Encounter 5 (6-enc) or 8 (9-enc)
  - Guidance: "Show item/location clearly. Prepare for finale."
  - Purpose: Reveal objective location, set up final encounter

- **Final (100%)**: Encounter 6 (6-enc) or 9 (9-enc)
  - Guidance: Quest-specific completion instructions
  - Purpose: Present objective for completion

**Example (6-encounter retrieval quest):**
1. Enc 1-2 (Early): Hints about ancient ruins, locals mention artifact rumors
2. Enc 3-4 (Mid): Find map fragment, discover ruins entrance
3. Enc 5 (Late): Enter ruins, see artifact on pedestal
4. Enc 6 (Final): Present artifact, offer "Take [artifact]" action

### Quest Types
Quest type is inferred from keywords in the `questGoal` text. Each type has specific final encounter handling:

1. **Retrieval Quests** (find, retrieve, locate, discover)
   - Final encounter: "final" type (non-combat)
   - Completion: Present artifact/item, LLM MUST offer "Take [artifact]" action, code marks completed=true when player takes it
   - Code-controlled: LLM cannot mark as complete, only TurnProcessor.handleQuestCompletion() can
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
- Max prompt length: 600 characters (reduced to fit within model's strict context limit)
- **Tier 1 Priority** (always preserved):
  - CRITICAL instructions (combat/quest completion rules)
  - QUEST STAGE (early/middle/finale guidance)
  - NEW ADVENTURE (signals fresh quest generation)
  - AVOID RECENT QUEST TYPES (quest variety enforcement)
  - Player action (current user input)
  - Encounter type (combat/social/exploration/etc.)
- **Tier 2 Priority** (preserved if space allows):
  - Quest goal (if <120 chars)
  - Location (if <50 chars)
  - Character stats (if <80 chars)
  - Monster info (always kept)
  - NPC info (always kept)
- **Tier 3 - Dropped** (nice-to-have context):
  - Recent actions history
  - Encounter count statistics
  - Long descriptions
- Ensures quest completion, variety, and combat instructions never get cut off

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
- **Consumable stacking**: Identical consumables (same baseName/effect) stack with quantity counter
- **Display format**: Items with quantity > 1 shown as "Item Name (x3)"
- **Usage**: Consuming an item decrements quantity; item removed when quantity reaches 0
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

### Test Structure
- Tests in `DunGenTests/` directory
- Swift Testing framework with `@Test` and `#expect`
- `MockGameEngine` for fast unit tests without LLM calls
- `LLMGameEngine` used directly for integration tests (device only)
- Unit tests for game logic (mock mode)
- Integration tests for LLM behavior (device only)
- Transcript-based tests for LLM prompt/response validation
- Level progression tests
- Character history tests
- Quest type validation tests

### Key Test Files
- `MockGameEngineTests.swift` - Tests mock engine functionality
- `QuestTypeTests.swift` - Tests 6 quest types (retrieval, combat, escort, investigation, rescue, diplomatic)
- `QuestProgressManagerTests.swift` - Tests quest progression guidance
- `FullAdventureIntegrationTest.swift` - Integration tests for complete adventures
- `EngineLevelingIntegrationTests.swift` - Tests XP and leveling
- `GameStatePersistenceTests.swift` - Tests save/load functionality
- `TranscriptIntegrationTests.swift` - Tests using Apple's Transcript API to validate LLM behavior
- `TranscriptTestHelpers.swift` - Utility methods for transcript analysis in tests

### Test Isolation Requirements
⚠️ **Critical**: LLM mode tests share `SystemLanguageModel.default` resource and can interfere with each other when run as a suite.

**Solution**: Add 500ms delay at start of all LLM mode tests:
```swift
@Test("LLM test", .enabled(if: isLLMAvailable()))
func testLLM() async throws {
    try? await Task.sleep(for: .milliseconds(500))
    let engine = MockGameEngine(mode: .llm)
    // test continues...
}
```

### LLM Test Setup Pattern
LLM mode tests require complete game initialization:
```swift
private func setupGameWithAdventure(engine: MockGameEngine, preferredType: AdventureType) async {
    await engine.startNewGame(preferredType: preferredType, usedNames: [])
    if engine.awaitingWorldContinue {
        await engine.continueNewGame(usedNames: [])
    }
    if engine.awaitingLocationSelection, let firstLocation = engine.worldState?.locations.first {
        await engine.submitPlayer(input: firstLocation.name)
    }
}
```

### Manager Initialization
Tests using `LLMGameEngine` directly must call `setupManagers()`:
```swift
let engine = LLMGameEngine(levelingService: DefaultLevelingService())
engine.setupManagers() // Required to initialize TurnProcessor, etc.
```

### Transcript Testing
The game uses Apple's `Transcript` API to validate LLM behavior and establish feedback loops for improvements.

**TranscriptTestHelpers Utility:**
- `verifyPromptContains()` - Check if keyword appears in any prompt
- `verifyAllPromptsContain()` - Check if keyword appears in ALL prompts
- `getLastPrompt()` - Get most recent prompt text
- `getLastResponse()` - Get most recent response text
- `getPromptHistory()` - Get all prompts chronologically
- `getPromptsMissing()` - Find prompts missing a keyword
- `analyzeContextUsage()` - Get character-based metrics (size, count, over-limit warnings)
- `analyzeTokenUsage()` - Get token-based analysis (estimates tokens, % of 4096 budget used)
- `estimateTokens()` - Convert characters to estimated token count (÷4 approximation)
- `entryCount()`, `promptCount()`, `averagePromptSize()`, `maxPromptSize()` - Basic metrics

**Example Test:**
```swift
@Test("Quest context maintained", .enabled(if: isLLMAvailable()))
func testQuestContext() async throws {
    try? await Task.sleep(for: .milliseconds(500))
    let engine = MockGameEngine(mode: .llm)
    await setupGameWithAdventure(engine, preferredType: .village)

    let questGoal = engine.adventureProgress?.questGoal ?? ""

    for i in 1...5 {
        await engine.submitPlayer(input: "explore")

        let transcript = engine.getTranscript(for: .adventure)
        let hasQuest = TranscriptTestHelpers.verifyPromptContains(
            transcript: transcript,
            keyword: questGoal
        )

        #expect(hasQuest, "Quest missing from prompt in turn \(i)")
    }
}
```

**Automatic Logging:**
- `SpecialistSessionManager` logs transcript metrics after each use
- `TurnProcessor` logs metrics on adventure completion
- Metrics tracked: entry count, prompt count, avg/max size, token estimates, over-limit counts
- Warnings logged when transcript approaches 4096 token limit (85%+ usage)

See `TESTING.md` for complete testing guide.
