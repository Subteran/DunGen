# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DunGen is an iOS 26 fantasy RPG text adventure game that uses Apple's on-device LLM (FoundationModels framework) to generate immersive narratives, character interactions, and dynamic gameplay. The game features:

- **Permadeath rogue-like gameplay** with character history tracking
- **11 specialist LLMs** working together for coherent game experiences
- **Dynamic combat system** with dedicated UI
- **100 base monsters** with procedural affix modifications
- **Persistent NPCs** that remember player interactions
- **Equipment system** with prefix/suffix affixes
- **Character progression** with 6 classes and level-based rewards
- **Scroll-responsive UI** with bottom sheet actions

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
│   └── LLMGameEngine.swift   # Core game engine (549 lines)
├── Managers/
│   ├── CombatManager.swift           # Combat state and logic
│   ├── AffixRegistry.swift           # Item/monster affix tracking
│   ├── NPCRegistry.swift             # NPC persistence
│   ├── SpecialistSessionManager.swift # LLM session management
│   ├── GameStatePersistence.swift    # Save/load system
│   └── LevelingService.swift         # XP and leveling logic
├── Models/
│   ├── WorldModels.swift         # AdventureType, WorldState, AdventureProgress
│   ├── CharacterModels.swift     # CharacterProfile, LevelReward
│   ├── MonsterModels.swift       # MonsterDefinition, MonsterAffix
│   ├── NPCModels.swift           # NPCDefinition, NPCDialogue
│   ├── ItemModels.swift          # ItemDefinition, ItemAffix
│   ├── EncounterModels.swift     # EncounterDetails, ProgressionRewards
│   ├── CharacterHistory.swift    # DeceasedCharacter, CharacterDeathReport
│   ├── MonsterDatabase.swift     # 100 base monsters
│   ├── CharacterClass.swift      # Class definitions
│   └── Item.swift                # SwiftData model
├── Views/
│   ├── GameView.swift            # Main narrative + scroll-based action sheet
│   ├── CharacterView.swift       # Character stats display
│   ├── CombatView.swift          # Dedicated combat interface
│   ├── DeathReportView.swift     # Final statistics on death
│   ├── CharacterHistoryView.swift # Fallen heroes list
│   ├── ItemDetailView.swift      # Equipment details
│   └── ContentView.swift         # Tab navigation
└── Resources/
    ├── L10n.swift                # Localization constants
    └── en.lproj/
        └── Localizable.strings   # All strings including LLM instructions
```

## Architecture

### Multi-LLM Specialist System

The game uses **11 specialized LLMs** instead of one monolithic LLM. Each specialist has a focused responsibility:

1. **World LLM** - Generates fantasy worlds with 2-5 diverse starting locations
2. **Encounter LLM** - Determines encounter type (combat/social/exploration/puzzle/trap/stealth/chase) and difficulty
3. **Adventure LLM** - Creates narrative text (2-4 paragraphs) and manages adventure progression
4. **Character LLM** - Generates unique level 1 characters with 6 classes (Rogue/Warrior/Mage/Healer/Paladin/Ranger)
5. **Equipment LLM** - Creates items using consistent prefix/suffix affix system
6. **Progression LLM** - Calculates XP, HP, gold rewards and determines loot drops
7. **Abilities LLM** - Generates physical abilities for Rogue/Warrior/Ranger
8. **Spells LLM** - Creates arcane spells for Mage
9. **Prayers LLM** - Generates divine prayers for Healer/Paladin
10. **Monsters LLM** - Modifies base monsters (from 100-monster database) with affixes
11. **NPC LLM** - Creates and manages persistent NPCs with dialogue

**Key Design Principles:**
- Specialists work in sequence during `advanceScene()`
- Each specialist has detailed instructions in `Localizable.strings`
- Session resets every 3 turns via `SpecialistSessionManager`
- Consistent affix system across Equipment and Monster LLMs
- NPC persistence tracked in `NPCRegistry`

### Core Components

**LLMGameEngine** (`LLM/LLMGameEngine.swift`)
- Main game orchestrator using Apple's FoundationModels
- Marked with `@MainActor` and `@Observable` for SwiftUI integration
- Uses `@Generable` and `@Guide` macros for structured LLM output
- Delegates to specialized managers (CombatManager, NPCRegistry, AffixRegistry)
- Coordinates 11 specialist LLMs for coherent gameplay
- Manages game state: character, world, adventure progress
- Handles death detection and report generation

**CombatManager** (`Managers/CombatManager.swift`)
- Manages combat state: `inCombat`, `currentMonster`, `currentMonsterHP`
- Handles combat actions: attack, flee, surrender
- Tracks monsters defeated
- Weak reference to game engine for `appendModel()` and `checkDeath()`

**AffixRegistry** (`Managers/AffixRegistry.swift`)
- Tracks known item and monster affixes for consistency
- Ensures "Flaming" always means fire damage across all items
- Prevents affix definition drift

**NPCRegistry** (`Managers/NPCRegistry.swift`)
- Maintains NPC persistence by location
- Tracks interaction counts
- 50% chance to reuse existing NPCs when returning to locations

**SpecialistSessionManager** (`Managers/SpecialistSessionManager.swift`)
- Manages 11 separate `LanguageModelSession` instances
- Resets sessions every 3 turns to prevent context overflow
- Each specialist has dedicated system instructions

**GameStatePersistence** (`Managers/GameStatePersistence.swift`)
- JSON-based save/load in Documents directory
- Saves character, location, environment, log entries, inventory
- Auto-saves after major actions

**LevelingService** (`Managers/LevelingService.swift`)
- Protocol-based design (`LevelingServiceProtocol`)
- Logarithmic XP progression (levels 1-15+)
- Level-up: HP gain (1d8 + CON modifier), random stat increases
- Stats can exceed 20 through leveling

### Data Flow

**Game Start:**
1. `GameView.task` → `checkAvailabilityAndConfigure()` → `loadState()`
2. If no character → `startNewGame()`
3. World LLM generates world → Character LLM creates character
4. First `advanceScene()` begins adventure

**Turn Loop:**
1. Player selects action from bottom sheet → `submitPlayer(input:)`
2. `advanceScene()` orchestrates specialists:
   - Encounter LLM determines type/difficulty
   - Monster LLM or NPC LLM generates entities (if needed)
   - Adventure LLM creates narrative
   - Progression LLM calculates rewards
   - Equipment LLM generates loot (if dropped)
3. `apply(turn:, encounter:, rewards:, loot:, monster:, npc:)` updates game state
4. XP/gold applied, HP changed, items added to inventory
5. `LevelingService` handles level-ups (HP, stats, abilities/spells)
6. `saveState()` persists progress
7. UI updates via `@Observable`

**Combat Flow:**
1. Monster encounter → `CombatManager.enterCombat()`
2. `GameView` detects `engine.inCombat` → shows `CombatView`
3. Player chooses action → `CombatManager.performCombatAction()`
4. Damage calculated, HP updated, death checked
5. Victory → `monstersDefeated++`, combat ends
6. Defeat → `checkDeath()` → death report

**Death Flow:**
1. HP ≤ 0 → `checkDeath()` creates `CharacterDeathReport`
2. Report includes: final level, XP, gold, adventures/monsters/items stats, play time
3. `GameView` shows `DeathReportView` in fullScreenCover
4. Player taps "Start New Adventure" → saves to `DeceasedCharacter` (SwiftData)
5. New game begins

### UI Structure

**GameView** (`Views/GameView.swift`)
- Main narrative display with `ScrollView` and `ScrollViewReader`
- Character status bar: Level, HP, XP, Gold badges
- **Scroll-responsive action sheet:**
  - `ScrollOffsetPreferenceKey` tracks scroll position
  - Sheet opens when scrolled to bottom (offset > -10)
  - Sheet closes when scrolled up (offset < -50)
  - Sheet closes after action selection
- Custom input option available
- Full-screen covers for combat and death report

**CombatView** (`Views/CombatView.swift`)
- Dedicated combat interface
- Monster display: name, description, HP/DMG/DEF, abilities
- Player options: Attack, Use Ability, Cast Spell, Flee, Surrender
- Collapsible sections for abilities/spells

**CharacterView** (`Views/CharacterView.swift`)
- Character stats: name, race, class, level
- Attributes with modifiers: `(value - 10) / 2`
- Abilities, spells, inventory (detailed with ItemDefinition)
- Read-only display

**CharacterHistoryView** (`Views/CharacterHistoryView.swift`)
- Lists deceased characters via `@Query`
- Shows: name, level, race/class, death date, cause of death
- Detail view: full statistics including play time, adventures completed

**DeathReportView** (`Views/DeathReportView.swift`)
- Final statistics on death
- Fallen character summary
- Skills mastered (abilities/spells)
- "Start New Adventure" button

**ContentView** (`Views/ContentView.swift`)
- TabView with 4 tabs: Game, Character, History, Data
- Shared `LLMGameEngine` instance
- Availability indicator in toolbar
- SwiftData modelContainer for DeceasedCharacter

## Key Patterns

### Protocol-Oriented Design
All major components use protocols for testability:
- `GameEngineProtocol` - Game engine interface
- `LevelingServiceProtocol` - Leveling calculations
- `GameStatePersistenceProtocol` - Save/load

### Actor Isolation
- `LLMGameEngine` is `@MainActor` with `nonisolated` initializers
- Managers are `@MainActor` and `@Observable`
- `checkAvailabilityAndConfigure()` called from `GameView.task`

### Guided Generation
Use `@Generable` for LLM-generated types and `@Guide` for field constraints:
```swift
@Generable(description: "A fantasy character")
struct CharacterProfile: Codable {
    @Guide(description: "Character name")
    var name: String
    @Guide(description: "Hit points", .range(8...14))
    var hp: Int
}
```

### Manager Pattern
- **CombatManager** - Handles all combat logic
- **AffixRegistry** - Ensures affix consistency
- **NPCRegistry** - Manages NPC persistence
- **SpecialistSessionManager** - Coordinates LLM sessions

### Single Responsibility Principle
- Models separated by domain (World, Character, Monster, NPC, Item, Encounter)
- Views separated by purpose (Game, Combat, Death, History)
- Managers handle specific subsystems

## Key Features

### Permadeath System
- Character death triggers final report
- Statistics saved to SwiftData (`DeceasedCharacter`)
- History tab shows fallen heroes
- Each death includes cause, stats, play time

### Combat System
- Dedicated `CombatView` with monster details
- Attack, abilities, spells, prayers
- Flee (60% success) or surrender options
- Monster HP tracking
- Death checking after each round

### Equipment System
- Prefix/suffix affix system
- Consistent effects (e.g., "Flaming" always = fire damage)
- Rarity tiers: common, uncommon, rare, epic, legendary
- Loot drops based on encounter difficulty

### Monster System
- 100 base monsters in `MonsterDatabase`
- Level-scaled HP/damage/defense
- Affixes modify stats and add abilities
- Examples: "Ancient Goblin of Shadows", "Frenzied Troll the Eternal"

### NPC System
- Persistent NPCs at locations
- Interaction counting
- Relationship tracking: neutral, friendly, hostile, allied
- Dynamic dialogue based on history
- Quest hooks

### Leveling System
- Logarithmic XP curve (100, 300, 600, 1000, 1500...)
- HP gain on level-up: 1d8 + CON modifier
- Random stat increases (1-3 points)
- New abilities/spells/prayers at certain levels

## Localization

All strings in `Resources/en.lproj/Localizable.strings`:
- UI strings accessed via `L10n` constants
- LLM specialist instructions (11 detailed prompts)
- Format strings use `trKey()` helper

Example:
```swift
Text(L10n.tabGameTitle)  // "Adventure"
String(format: L10n.gameIntroFormat, name, race, className)
```

## Testing Approach

- Tests in `DunGenTests/` directory
- Swift Testing framework
- Mock implementations for protocols
- Integration tests for LLM behavior
- Level progression tests
- Character history tests

## State Management

**Character State:**
- `CharacterProfile` - current character
- Attributes, HP, XP, gold, inventory (strings + ItemDefinition)
- Abilities (physical), spells (arcane), prayers (divine)

**World State:**
- `WorldState` - world story + locations
- `AdventureProgress` - current adventure tracking (X/Y encounters)
- `currentEnvironment` - specific location description

**Combat State:**
- `CombatManager.inCombat` - in combat flag
- `CombatManager.currentMonster` - active monster
- `CombatManager.currentMonsterHP` - monster health

**Statistics:**
- `gameStartTime` - for play time calculation
- `adventuresCompleted` - adventure count
- `monstersDefeated` - kill count
- `itemsCollected` - loot count

## Important Notes

### Context Window Management
- Sessions reset every 3 turns
- Context summary provides condensed state after resets
- Environment tracking maintains location continuity
- Recent encounter types prevent repetition

### Scroll-Based UI
- Action sheet appears when scrolled to bottom
- Sheet dismisses when scrolling up
- Allows reading full narrative without obstruction
- Background interaction enabled

### LLM Specialist Coordination
- Encounter LLM determines challenge type
- Monster/NPC LLM generates entities based on type
- Adventure LLM writes narrative incorporating entities
- Progression LLM calculates rewards independently
- Equipment LLM generates loot if Progression LLM flags it

### Affix Consistency
- Equipment LLM registers item affixes in `AffixRegistry`
- Monster LLM registers monster affixes in `AffixRegistry`
- Both systems maintain consistency across game
- New affixes created sparingly

### NPC Persistence
- NPCs stored by location in `NPCRegistry`
- 50% reuse chance when returning to location
- Interaction count increments on each meeting
- Relationship can evolve based on player actions

### Death and Permadeath
- HP ≤ 0 triggers death
- Surrender in combat = instant death
- Final report shows all statistics
- Character saved to history database
- New game starts fresh character
