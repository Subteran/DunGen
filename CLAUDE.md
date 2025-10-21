# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DunGen is an iOS 26 fantasy RPG text adventure game that uses Apple's on-device LLM (FoundationModels framework) to generate immersive narratives, character interactions, and dynamic gameplay. The game features:

- **Permadeath rogue-like gameplay** with character history tracking
- **11 specialist LLMs** working together for coherent game experiences
- **16 character classes** across 8 races with racial stat modifiers
- **Sprite-based character visualization** using 4×4 grid sprite sheets
- **Dynamic combat system** with player-initiated combat and dedicated UI
- **Quest-based adventures** with clear objectives and progression tracking
- **112 base monsters** (7 groups of 16) with procedural affix modifications
- **Persistent NPCs** that remember player interactions
- **Equipment system** with prefix/suffix affixes and 20-slot inventory limit
- **Character progression** with level-based rewards and unique name verification
- **Loading overlay** during LLM generation
- **Context window protection** through prompt size management and post-generation verification

## Build & Test Commands

### Build
```bash
xcodebuild -scheme DunGen -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build
```

### Run Tests
```bash
xcodebuild test -scheme DunGen -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
```

### Run Single Test
```bash
xcodebuild test -scheme DunGen -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' -only-testing:DunGenTests/TestClassName/testMethodName
```

## Project Structure

```
DunGen/
├── DunGenApp.swift           # Main app entry point
├── LLM/
│   └── LLMGameEngine.swift   # Core game engine with prompt size safeguards
├── Managers/
│   ├── CombatManager.swift           # Combat state with pending monster system
│   ├── AffixRegistry.swift           # Item/monster affix tracking
│   ├── NPCRegistry.swift             # NPC persistence
│   ├── SpecialistSessionManager.swift # LLM session management (resets every 15 turns)
│   ├── GameStatePersistence.swift    # Save/load system
│   └── LevelingService.swift         # XP and leveling logic
├── Models/
│   ├── WorldModels.swift         # AdventureType, WorldState, AdventureProgress, AdventureSummary
│   ├── CharacterModels.swift     # CharacterProfile (16 classes), RaceModifiers, LevelReward
│   ├── MonsterModels.swift       # MonsterDefinition, MonsterAffix
│   ├── NPCModels.swift           # NPCDefinition, NPCDialogue
│   ├── ItemModels.swift          # ItemDefinition with UUID, ItemAffix
│   ├── EncounterModels.swift     # EncounterDetails, ProgressionRewards
│   ├── CharacterHistory.swift    # DeceasedCharacter, CharacterDeathReport
│   ├── MonsterDatabase.swift     # 112 base monsters
│   ├── CharacterClass.swift      # 16 class definitions with grid positions
│   └── Item.swift                # SwiftData model
├── Views/
│   ├── GameView.swift            # Main narrative with loading overlay and adventure summary
│   ├── CharacterView.swift       # Character stats display
│   ├── CombatView.swift          # Dedicated combat interface
│   ├── DeathReportView.swift     # Final statistics on death
│   ├── CharacterHistoryView.swift # Fallen heroes list
│   ├── ItemDetailView.swift      # Equipment details
│   ├── InventoryManagementView.swift # 20-slot inventory manager
│   ├── WorldView.swift           # Location browser
│   ├── SpriteSheet.swift         # Sprite extraction system
│   ├── PaperDollView.swift       # Character sprite display
│   └── ContentView.swift         # Tab navigation
└── Resources/
    ├── L10n.swift                # Localization constants
    ├── art/                      # Sprite sheet source images (8 races)
    └── en.lproj/
        └── Localizable.strings   # All strings including LLM instructions (11 specialists)
```

## Architecture

### Multi-LLM Specialist System

The game uses **11 specialized LLMs** instead of one monolithic LLM. Each specialist has a focused responsibility:

1. **World LLM** - Generates fantasy worlds with 2-5 diverse starting locations
2. **Encounter LLM** - Determines encounter type (combat/social/exploration/puzzle/trap/stealth/chase/final) and difficulty
3. **Adventure LLM** - Creates narrative text (2-4 sentences) with quest progression
4. **Character LLM** - Generates unique level 1 characters with 16 classes and 8 races
5. **Equipment LLM** - Creates items using consistent prefix/suffix affix system
6. **Progression LLM** - Calculates XP, HP, gold rewards (strict reward philosophy)
7. **Abilities LLM** - Generates physical abilities for non-caster classes
8. **Spells LLM** - Creates arcane/nature/death/eldritch spells for caster classes
9. **Prayers LLM** - Generates divine prayers for divine classes
10. **Monsters LLM** - Modifies base monsters (from 112-monster database) with affixes
11. **NPC LLM** - Creates and manages persistent NPCs with dialogue

**Key Design Principles:**
- Specialists work in sequence during `advanceScene()`
- Each specialist has detailed instructions in `Localizable.strings`
- Session resets every 15 turns via `SpecialistSessionManager`
- Consistent affix system across Equipment and Monster LLMs
- NPC persistence tracked in `NPCRegistry`
- **Post-generation verification** for duplicate detection (locations, NPCs, abilities/spells)
- **Prompt size protection** - no unbounded lists sent to LLMs

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
- Each race has a 4×4 sprite sheet (2048×2048, 512×512 per sprite)
- `RaceClassSprite` extracts correct sprite based on race + class
- Sprite sheets named: `{race}_sheet.png` (e.g., `dwarf_sheet.png`)
- `CharacterClass.gridPosition` maps each class to grid coordinates
- `PaperDollView` displays single sprite (no composition)

### Context Window Protection

**Critical safeguards to prevent prompt size overflow:**

1. **Inventory Limit** - 20-slot maximum with inventory management UI
2. **Location Cap** - Maximum 50 locations total
3. **User Input Truncation** - Player actions limited to 500 characters
4. **Action History Truncation** - Recent actions truncated to 200 characters each
5. **Post-Generation Verification**:
   - Locations: Generate without existing list, verify duplicates, regenerate if needed
   - NPCs: Generate without existing list, verify duplicates, regenerate if needed
   - Abilities/Spells: Generate without existing list, verify duplicates, regenerate if needed
6. **Session Resets** - Every 15 turns to clear conversation history

### Core Components

**LLMGameEngine** (`LLM/LLMGameEngine.swift`)
- Main game orchestrator using Apple's FoundationModels
- Marked with `@MainActor` and `@Observable` for SwiftUI integration
- Uses `@Generable` and `@Guide` macros for structured LLM output
- Delegates to specialized managers (CombatManager, NPCRegistry, AffixRegistry)
- Coordinates 11 specialist LLMs for coherent gameplay
- Manages game state: character, world, adventure progress, quest tracking
- Handles death detection and report generation
- **Generation state tracking** (`isGenerating`) for loading overlay
- **Inventory management** triggers when 20-slot limit exceeded
- **Character name deduplication** with post-generation verification
- **Adventure summary system** tracks XP/gold/monsters per adventure

**CombatManager** (`Managers/CombatManager.swift`)
- Manages combat state: `inCombat`, `currentMonster`, `currentMonsterHP`, `pendingMonster`
- **Player-initiated combat** - monster displayed as pending, player chooses to attack
- Handles combat actions: attack, flee, surrender
- Tracks monsters defeated
- Weak reference to game engine for `appendModel()` and `checkDeath()`

**SpecialistSessionManager** (`Managers/SpecialistSessionManager.swift`)
- Manages 11 separate `LanguageModelSession` instances
- **Resets sessions every 15 turns** to prevent context overflow
- Each specialist has dedicated system instructions
- Tracks turn count and triggers resets

### Adventure Flow

**Game Start → Adventure Creation:**
1. New game initialization → character generation (with racial modifiers)
2. World generation → 2-5 starting locations
3. Player chooses location
4. First adventure scene begins

**Adventure Structure:**
- Each adventure has `questGoal`, `locationName`, `adventureStory`
- 7-12 encounters per adventure
- Progress tracked: `currentEncounter` / `totalEncounters`
- Stats tracked: XP gained, gold earned, monsters defeated

**Encounter Types:**
- **Combat**: Monster appears → player attacks → combat system
- **Social**: NPC interaction → dialogue/trade
- **Exploration**: Environmental challenges/discoveries
- **Puzzle**: Logic/riddle challenges
- **Trap**: Danger requiring reaction (scales with player level)
- **Final**: Last encounter that satisfies quest goal

**Scene Advancement (Each Turn):**
1. Encounter Generation: Type and difficulty
2. Entity Creation:
   - Combat → Generate monster with affixes
   - Social → Generate or retrieve NPC
   - Exploration → Explore the area
3. Turn Narration: 2-4 sentences describing scene
4. Rewards Calculation: XP/gold/HP/loot based on difficulty
5. Action Suggestions: 2 distinct choices for player

**Adventure Completion:**
1. When `currentEncounter >= totalEncounters` AND `completed = true`
2. Generate adventure summary with stats
3. Show summary sheet to player
4. Player clicks "Choose Next Location"
5. Clear `showingAdventureSummary` flag
6. Prompt for next location selection

**Post-Adventure Flow:**
- Display adventure summary: location, quest, stats, notable items
- Player reviews completion
- Filter uncompleted locations
- Generate 3 new locations if < 2 uncompleted (max 50 total)
- Player selects next adventure

### Data Flow

**Game Start:**
1. `GameView.task` → `checkAvailabilityAndConfigure()` → `loadState()`
2. If no character → `startNewGame(usedNames:)`
3. World LLM generates world → Character LLM creates character (with name verification + racial modifiers)
4. Player selects starting location
5. First `advanceScene()` begins adventure with quest

**Turn Loop:**
1. Player selects action → `submitPlayer(input:)` (truncated to 500 chars)
2. `isGenerating = true` triggers loading overlay
3. `advanceScene()` orchestrates specialists:
   - Encounter LLM determines type/difficulty
   - Monster LLM generates pending monster (if combat) - player must initiate
   - NPC LLM generates/retrieves NPC (if social) with duplicate verification
   - Adventure LLM creates narrative (2-4 sentences) with quest context
   - Progression LLM calculates rewards (strict philosophy)
   - Equipment LLM generates loot (if dropped)
4. `apply(turn:, encounter:, rewards:, loot:, monster:, npc:)` updates game state
5. Inventory overflow triggers inventory management UI
6. XP/gold applied, HP changed, level-ups handled with reward generation
7. `saveState()` persists progress
8. `isGenerating = false` dismisses loading overlay

**Combat Flow:**
1. Monster encounter → `pendingMonster` set, monster stats displayed
2. Player chooses to attack/fight/engage → `CombatManager.enterCombat()`
3. `GameView` detects `engine.inCombat` → shows `CombatView`
4. Player chooses action → `CombatManager.performCombatAction()`
5. Damage calculated, HP updated, death checked
6. Victory → `monstersDefeated++`, combat ends
7. Defeat → `checkDeath()` → death report

**Inventory Management Flow:**
1. Loot drops would exceed 20 slots → `needsInventoryManagement = true`
2. `GameView` shows `InventoryManagementView`
3. Player selects up to 20 items (current + new)
4. `finalizeInventorySelection()` applies choices
5. Game continues

**Quest System:**
1. Adventure LLM generates `questGoal` when starting new adventure
2. Quest displayed in Quest sheet (toolbar button)
3. Adventure LLM maintains quest consistency across encounters
4. Quest completion triggers location selection for next adventure

### UI Structure

**GameView** (`Views/GameView.swift`)
- Main narrative display with `ScrollView` and `ScrollViewReader`
- Character status bar: Level, HP, XP, Gold badges
- **Loading overlay** - Shows "creating..." during LLM generation
- **Quest button** - Displays current quest, location, story, progress
- **Adventure summary button** - Shows stats after adventure completion
- Actions sheet with suggested actions + custom input
- Full-screen covers for combat, death report, inventory management, adventure summary
- Fetches deceased character names for name deduplication

**InventoryManagementView** (`Views/InventoryManagementView.swift`)
- Two sections: Current Inventory (pre-selected) + New Items (unselected)
- Checkbox selection for each item
- Slot counter (X / 20) with visual feedback
- Item details: name, rarity (color-coded), effects
- Enforce 20-slot maximum - Confirm button disabled if exceeded
- Cancel option to discard new items

**CombatView** (`Views/CombatView.swift`)
- Dedicated combat interface
- Monster display: name, description, HP/DMG/DEF, abilities
- Player options: Attack, Use Ability, Cast Spell, Flee, Surrender
- Collapsible sections for abilities/spells

**CharacterView** (`Views/CharacterView.swift`)
- Character stats: name, race, class, level
- Attributes with modifiers: `(value - 10) / 2`
- **Conditional spell display** - Only shown if character has spells
- Abilities, spells, inventory (detailed with ItemDefinition)
- **PaperDollView** - Shows character sprite based on race + class

**WorldView** (`Views/WorldView.swift`)
- Displays all discovered locations
- Shows visited/completed status
- Location descriptions and types

**PaperDollView** (`Views/PaperDollView.swift`)
- Single sprite display using `RaceClassSprite.spriteView()`
- Extracts sprite from race's 4×4 sprite sheet
- Grid position determined by `CharacterClass.gridPosition`
- No sprite composition or layering

**SpriteSheet.swift**
- `SpriteView`: Generic sprite extraction from grid
- `RaceClassSprite`: Static method for race/class sprite lookup
- `CharacterClass.gridPosition`: Maps class to (row, column)
- Grid format: 4 columns × 4 rows

## Key Features

### Character Classes (16 Total)

**Martial Classes:**
- **Warrior** - Any weapons/armor, combat techniques
- **Rogue** - Light weapons, stealth, sneak attacks
- **Ranger** - Ranged weapons, tracking, nature skills
- **Monk** - Unarmed/quarterstaff, martial arts, ki powers
- **Barbarian** - Heavy weapons, rage, primal power
- **Assassin** - Daggers, poisons, stealth, precision strikes
- **Berserker** - Heavy weapons, battle frenzy, brutal strikes

**Divine Casters:**
- **Healer** - Healing prayers, restoration, protection
- **Paladin** - Holy combat, divine smites, auras
- **Cleric** - Divine magic, blunt weapons, protection

**Arcane Casters:**
- **Mage** - Arcane spells, elemental magic
- **Necromancer** - Death magic, undead summoning
- **Sorcerer** - Innate arcane magic, raw magical energy
- **Warlock** - Eldritch pact magic, dark spells

**Nature Casters:**
- **Druid** - Nature spells, shapeshifting, animal magic

**Hybrid:**
- **Bard** - Performance, inspiration, jack-of-all-trades

### Monster Database (112 Total)

**7 Groups of 16:**
- Group 1: Goblin, Kobold, Orc, Skeleton, Zombie, Wolf, Bear, Giant Rat, Giant Spider, Dire Wolf, Imp, Succubus, Hellhound, Lemure, Balor, Fire Elemental
- Group 2: Water Elemental, Earth Elemental, Air Elemental, Ice Elemental, Dragon Wyrmling, Drake, Wyvern, Ancient Dragon, Pseudodragon, Bandit, Cultist, Guard, Assassin, Berserker, Troll, Ogre
- Group 3: Hill Giant, Ettin, Cyclops, Ghost, Wraith, Vampire Spawn, Lich, Mummy, Eye Tyrant, Brain Eater, Aboleth, Transparent Ooze, Corrosion Crawler, Harpy, Manticore, Chimera
- Group 4: Hydra, Griffon, Pixie, Sprite, Dryad, Satyr, Hag, Minotaur, Medusa, Gorgon, Cockatrice, Basilisk, Gnoll, Bugbear, Hobgoblin, Troglodyte
- Group 5: Lizardfolk, Gargoyle, Golem, Animated Armor, Scarecrow, Homunculus, Banshee, Death Knight, Flameskull, Ghoul, Revenant, Phase Panther, Feathered Bear, Burrowing Maw, Ankheg, Phase Spider
- Group 6: Roper, Tunnel Horror, Grick, Cloaker, Otyugh, Nightmare, Invisible Stalker, Djinni, Efreeti, Salamander, Naga, Serpent Folk, Couatl, Pegasus, Unicorn, Shambling Mound
- Group 7: Treant, Myconid, Vine Blight, Awakened Shrub, Stirge, Bat Swarm, Scorpion, Crocodile, Boar, Panther, Shadow, Wight, Specter, Elemental Mephit, Living Statue, Plague Rat

**Note:** All D&D-trademarked monsters replaced with generic alternatives (Beholder→Eye Tyrant, Mind Flayer→Brain Eater, etc.)

### Quest System
- Each adventure has a clear `questGoal` (e.g., "Clear the bandits from the old mill")
- Quest button in toolbar shows: goal, location, story, progress (X/Y encounters)
- Adventure LLM maintains quest consistency across all encounters
- Completion triggers adventure summary then next location selection

### Combat System
- **Player-initiated** - Monsters appear as pending, player chooses to engage
- Dedicated `CombatView` with monster details
- Attack, abilities, spells, prayers
- Flee (60% success) or surrender options
- Monster HP tracking
- Death checking after each round
- **Combat resolution never in narrative** - all fighting in combat system

### Inventory System
- **20-slot maximum** enforced strictly
- Overflow triggers `InventoryManagementView`
- Player selects which items to keep (current + new)
- Each item has UUID for unique identification
- Item effects combine prefix + suffix affix effects

### Character Generation
- **Unique name verification** - Checks against deceased character history
- Up to 5 regeneration attempts for unique names
- If all fail, player manually enters name
- Random race and class selection for variety
- **Racial stat modifiers** applied after generation
- Starting location selection by player

### Reward System
- **Strict reward philosophy** - XP/gold only for:
  - Combat victories
  - Treasure finding (non-empty containers)
  - Challenge success (puzzles, obstacles)
  - Boss defeats
- No rewards for: social encounters, exploration, failed attempts, stealth, chases

### Location System
- Player chooses starting location after world generation
- **Max 50 locations** to prevent unbounded growth
- Auto-generates 3 new locations when < 2 uncompleted remain
- Tracks visited/completed status
- Location selection after adventure completion

### NPC System
- Persistent NPCs at locations with duplicate name verification
- Interaction counting
- Relationship tracking: neutral, friendly, hostile, allied
- Dynamic dialogue based on history
- 50% reuse chance when returning to location

### Adventure Summary System
- Tracks stats per adventure: XP gained, gold earned, monsters defeated
- Shows completion summary after final encounter
- Displays: location, quest goal, encounters completed, notable items
- "Choose Next Location" button clears flag and prompts for next adventure

## Important Implementation Details

### Post-Generation Verification Pattern

Used for locations, NPCs, and abilities/spells to prevent unbounded prompt growth:

1. **Initial generation** - No existing items listed in prompt
2. **Check for duplicates** - Compare against Set of existing items
3. **If duplicate found** - Regenerate with explicit exclusion instruction
4. **Only list duplicates** - Not entire history, just items that conflicted
5. **Max attempts** - 5-10 attempts before fallback behavior

Example:
```swift
// First attempt: clean prompt
var prompt = "Generate a new NPC for this location."

// Second attempt: only mention duplicates
if attempts > 1 {
    prompt += " IMPORTANT: Do NOT use these names: \(duplicates)."
}
```

### Loading State Management

- `isGenerating` flag tracks all async LLM operations
- Set to `true` at start of `startNewGame()` and `submitPlayer()`
- Set to `false` on completion or early return
- GameView shows overlay when `isGenerating == true`
- Nested async operations properly awaited (no separate Tasks)

### Prompt Size Protection

**Always avoid:**
- Listing all locations in generation prompts
- Listing all NPCs in generation prompts
- Listing all abilities/spells in generation prompts
- Unbounded user input
- Unbounded action history

**Instead use:**
- Post-generation verification
- Truncation (500 chars for input, 200 for history)
- Hard limits (20 inventory slots, 50 locations)
- Session resets (every 15 turns)

### Sprite Sheet System

**Asset Structure:**
- Location: `DunGen/Resources/art/{race}_sheet.png`
- Asset catalog: `Assets.xcassets/{race}_sheet.imageset/`
- Grid: 4 columns × 4 rows (2048×2048 total, 512×512 per sprite)
- Format: PNG with transparency

**Class to Grid Mapping:**
```swift
var gridPosition: (row: Int, column: Int) {
    switch self {
    case .rogue: return (0, 0)
    case .warrior: return (0, 1)
    case .mage: return (0, 2)
    case .healer: return (0, 3)
    case .paladin: return (1, 0)
    case .ranger: return (1, 1)
    case .monk: return (1, 2)
    case .bard: return (1, 3)
    case .druid: return (2, 0)
    case .necromancer: return (2, 1)
    case .barbarian: return (2, 2)
    case .warlock: return (2, 3)
    case .sorcerer: return (3, 0)
    case .cleric: return (3, 1)
    case .assassin: return (3, 2)
    case .berserker: return (3, 3)
    }
}
```

**Sprite Extraction:**
1. `RaceClassSprite.spriteView(race:className:size:)` creates view
2. Normalizes race name to lowercase
3. Loads `{race}_sheet` image from assets
4. Maps className to CharacterClass enum
5. Gets grid position from `CharacterClass.gridPosition`
6. `SpriteView` extracts sprite using offset calculation
7. Clipping frame ensures only one sprite shows

## Testing Approach

- Tests in `DunGenTests/` directory
- Swift Testing framework
- Mock implementations for protocols
- Integration tests for LLM behavior (LevelingTests.swift, EngineLevelingIntegrationTests.swift)
- Level progression tests
- Character history tests

## State Management

**Character State:**
- `CharacterProfile` - current character with 16 possible classes
- Attributes with racial modifiers applied
- HP, XP, gold, inventory (strings + ItemDefinition with UUID)
- Abilities (physical), spells (arcane/nature/death/eldritch), prayers (divine)
- Name uniqueness enforced via deceased character check

**World State:**
- `WorldState` - world story + locations (max 50)
- `AdventureProgress` - includes `questGoal` field
- `AdventureSummary` - completion stats
- `currentEnvironment` - specific location description
- Location tracking: visited, completed flags

**Combat State:**
- `CombatManager.inCombat` - in combat flag
- `CombatManager.pendingMonster` - monster awaiting player decision
- `CombatManager.currentMonster` - active monster in combat
- `CombatManager.currentMonsterHP` - monster health

**Inventory State:**
- `detailedInventory` - ItemDefinition array (max 20 items, enforced)
- `needsInventoryManagement` - triggers overflow UI
- `pendingLoot` - items awaiting player selection

**Statistics:**
- `gameStartTime` - for play time calculation
- `adventuresCompleted` - adventure count
- `monstersDefeated` - kill count
- `itemsCollected` - loot count
- `currentAdventureXP` - XP gained this adventure
- `currentAdventureGold` - Gold earned this adventure
- `currentAdventureMonsters` - Monsters defeated this adventure

## Important Notes

### Session Management
- Sessions reset every **15 turns** (not 3)
- Context summary provides condensed state after resets
- Includes quest context in summaries
- Truncates long action history

### Combat Initiation
- Monsters appear as **pending**, not auto-combat
- Player must choose "attack", "fight", or "engage" keywords
- Allows negotiation, fleeing, or alternate approaches
- Gives player agency in all encounters
- **Combat never resolved in narrative** - only in combat system

### Character Name Uniqueness
- All deceased character names fetched from SwiftData
- Post-generation verification checks for duplicates
- Up to 5 regeneration attempts
- Manual input fallback if all fail
- Prevents duplicate names across game history

### Inventory Management
- Strict 20-slot limit prevents unbounded growth
- Overflow triggers selection UI automatically
- Player chooses which items to keep
- Old items can be discarded for new loot
- Prevents context window issues from large inventories

### Prompt Size Strategy
- **Never** send full lists to LLMs
- Use post-generation verification instead
- Only mention duplicates when regenerating
- Keep prompts bounded and constant-sized
- Allows indefinite gameplay without overflow

### Adventure Summary Bug Fix
- `showingAdventureSummary` flag must be cleared when choosing next location
- Without clearing, player gets stuck seeing "View Adventure Summary" button
- Fixed in GameView.swift:484 by adding `engine.showingAdventureSummary = false`

### Racial Stat Modifiers
- Applied after character generation via `RaceModifiers.modifiers(for:).apply(to:)`
- Stats clamped to 5-20 range
- Applied to both regular and custom-named characters
- Modifiers defined in CharacterModels.swift

### Sprite Sheet Requirements
- Need 8 sprite sheets (one per race): human, elf, dwarf, halfling, half-elf, half-orc, gnome, ursa
- Each sheet: 4×4 grid showing all 16 classes
- Image size: 2048×2048 (512×512 per sprite)
- Currently only dwarf_sheet.png implemented
- Missing sheets will cause runtime errors when displaying those races
