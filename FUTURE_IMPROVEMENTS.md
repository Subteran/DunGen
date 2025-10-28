# Future Improvements

This document tracks potential enhancements and feature ideas for DunGen. These are not committed work items, but rather a persistent list of possibilities to consider.

---

## Narrative & Quality

### Context & Memory
- **Entity Cards System**: Replace prose memories with short fixed-width "cards" (≤80 chars each) referenced by IDs
- **Open Threads Tracking**: Track narrative threads with `due≤N` windows to enforce payoff timing
- **Consistency Contract (CC)**: Ultra-compact state line for POV/tense/time/weather/location threaded through all prompts
- **Codebook Lexicon**: Per-biome token dictionary to compress repeated descriptions (e.g., `CROW_TOTEM="charred crow totem"`)
- **Delta Memories**: Store only state changes between turns, reconstruct full context on-device

### Narrative Quality
- **Beat Templates**: Quality scaffolding per encounter type (exploration, social, combat) with 2-5 sentence structures
- **Narrative Linter**: Pre-sanitizer for POV/tense fixes, number → diegesis conversion, acquisition verb handling
- **Judge → FixIt Loop**: Quality gate system that only runs correction pass when consistency/variety scores drop
- **Micro-Styles (STY)**: 4 tone presets (somber/brisk/wry/lyrical) for narrative variety
- **Rhythm Manager**: Enforce sentence length patterns across turns (short → medium → short → medium/long)
- **Sensory Rotation**: Rotate sensory details (sight → sound → smell → touch) to avoid repetition

### Testing
- **Offline Quality Tests**: 200-turn simulations measuring entity drift, thread closure rate, variety score, quest pace
- **Transcript Analysis**: Automated analysis of LLM transcripts for consistency violations

---

## Gameplay Systems

### Character Progression
- **Skill Trees**: Class-specific skill progression trees
- **Feat System**: Unlockable character feats at certain levels
- **Multiclassing**: Allow characters to combine classes at higher levels
- **Prestige Classes**: Advanced classes unlocked after meeting requirements

### Combat & Abilities
- **Status Effects System**: Poison, burn, freeze, stun, etc. with duration tracking
- **Combo System**: Abilities that chain or synergize with each other
- **Positioning**: Simple tactical positioning (melee/ranged)
- **Environmental Combat**: Use environment in combat (cover, hazards, etc.)
- **Difficulty Modes**: Easy/Normal/Hard/Permadeath options

### Quests & World
- **Dynamic Events**: Random world events that affect multiple locations
- **Faction System**: Track reputation with different factions
- **Branching Questlines**: Quests that offer meaningful choices affecting outcomes
- **Settlement Building**: Build/upgrade a home base between adventures
- **Companion System**: Recruit NPCs as temporary party members

### Items & Equipment
- **Crafting System**: Combine items to create new equipment
- **Set Items**: Equipment sets with bonus effects when worn together
- **Enchanting**: Modify existing items with new properties
- **Legendary Artifacts**: Unique named items with special abilities and lore
- **Durability System**: Equipment degrades and requires repair

---

## Technical Improvements

### Performance & Optimization
- **Response Caching**: Cache common LLM responses for frequently visited locations
- **Async Image Loading**: Better sprite sheet loading and caching
- **Background Save**: Auto-save on app backgrounding
- **Memory Optimization**: Profile and optimize memory usage during long sessions

### UI/UX
- **Accessibility Features**: VoiceOver support, dynamic type, high contrast mode
- **Customizable UI**: Theme options, font size preferences
- **Quick Actions**: Swipe gestures for common actions
- **Combat Log**: Detailed combat history view
- **Map View**: Visual representation of explored locations
- **Achievement System**: Track notable accomplishments

### Data & Persistence
- **iCloud Sync**: Sync characters and progress across devices
- **Export/Import**: Export characters/worlds for sharing
- **Statistics Dashboard**: Detailed gameplay statistics and analytics
- **Replay System**: Review past adventures from character history
- **Backup/Restore**: Manual backup and restore functionality

---

## Content Expansion

### Monsters & Enemies
- **Boss Abilities**: Unique boss-only abilities and mechanics
- **Monster Variants**: Environmental variants of base monsters (swamp skeleton vs cave skeleton)
- **Legendary Encounters**: Rare, powerful enemies with unique loot
- **Monster Evolution**: Monsters that grow stronger as player progresses

### Locations & Biomes
- **New Biome Types**: Desert, tundra, swamp, volcanic, celestial, etc.
- **Multi-Level Dungeons**: Dungeons with multiple floors and sub-areas
- **Dynamic Weather**: Weather that affects gameplay (fog reduces visibility, rain affects fire spells)
- **Time of Day**: Day/night cycle affecting encounters and NPCs

### Classes & Races
- **New Classes**: Artificer, Summoner, Battle Mage, etc.
- **New Races**: Tiefling, Dragonborn, Orc, etc.
- **Racial Abilities**: Active abilities based on race
- **Class Specializations**: Subclass options at mid-levels

---

## Quality of Life

### Player Convenience
- **Quick Combat**: Option to auto-resolve trivial combats
- **Batch Actions**: Use multiple consumables at once
- **Favorite Items**: Mark important items as favorites
- **Item Comparison**: Side-by-side equipment comparison
- **Undo Action**: Undo last action in certain situations
- **Save Presets**: Save different character builds/loadouts

### Information Display
- **Glossary**: In-game glossary for terms, monsters, items
- **Tutorial System**: Better onboarding for new players
- **Help System**: Context-sensitive help
- **Damage Calculator**: Show expected damage before attacks
- **Probability Display**: Show chances for success/failure

---

## Experimental Ideas

### AI/LLM Enhancements
- **Voice Narration**: Text-to-speech for narrative (using system TTS)
- **Dynamic Difficulty**: AI adjusts difficulty based on player performance
- **Personalized Content**: LLM learns player preferences over time
- **Player Modeling**: Adapt story and challenges to player style

### Social Features
- **Leaderboards**: Compare achievements with other players
- **Challenge Mode**: Daily/weekly challenges with leaderboards
- **Ghost Data**: See how other players approached same quests
- **Content Sharing**: Share interesting encounters or loot

### Meta Progression
- **Legacy System**: Bonuses for subsequent characters based on past achievements
- **Unlock System**: Unlock new options through gameplay (classes, races, locations)
- **Achievement Rewards**: Gameplay bonuses for completing achievements
- **Challenge Runs**: Special game modes (low health, no items, speed runs)

---

## Notes

- Items in this document are **not prioritized** - they're just possibilities
- Some ideas may be infeasible due to on-device LLM constraints
- Some ideas may conflict with the permadeath/rogue-like design philosophy
- This is a living document - add ideas as they come up, remove if implemented or rejected
- When implementing something from this list, move details to a proper design doc
