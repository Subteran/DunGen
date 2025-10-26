# LLMGameEngine Refactoring Plan

## Goal
Decouple game logic from UI concerns to enable:
1. Automated play testing without UI overhead
2. Background gameplay simulation for data collection
3. Parallel execution of multiple adventures
4. Training dataset generation

## Current Issues

### 1. UI Dependencies
- `@MainActor` on GameEngine protocol forces UI thread
- SwiftUI import in LLMGameEngine
- `@Observable` macro requires SwiftUI
- UI state properties mixed with game logic

### 2. Architecture Problems
```
Current:
Views → LLMGameEngine (UI State + Game Logic)

Desired:
Views → GameViewModel (UI State) → LLMGameEngine (Pure Logic)
Tests → AdventurePlayTest → LLMGameEngine (Pure Logic)
```

## Refactoring Steps

### Phase 1: Create Pure Core
- [ ] Remove `@MainActor` from GameEngine protocol
- [ ] Replace `@Observable` with manual observation pattern
- [ ] Remove SwiftUI import from LLMGameEngine
- [ ] Add `GameEngineDelegate` for UI callbacks

### Phase 2: Extract UI State
- [ ] Create `GameViewModel` wrapper class
- [ ] Move UI state properties to GameViewModel:
  - `isGenerating`
  - `suggestedActions` (for button display)
  - `awaitingLocationSelection`
  - `showingAdventureSummary`
  - `awaitingCustomCharacterName`
  - `needsInventoryManagement`
  - `awaitingWorldContinue`
- [ ] Keep game state in LLMGameEngine:
  - `character`
  - `adventureProgress`
  - `worldState`
  - `detailedInventory`
  - `log`

### Phase 3: Threading Model
```swift
// Current (Main thread only)
@MainActor
final class LLMGameEngine: GameEngine {
    func submitPlayer(input: String) async { }
}

// New (Any thread, delegates to main when needed)
final class LLMGameEngine: GameEngine {
    weak var delegate: GameEngineDelegate?

    func submitPlayer(input: String) async {
        // Game logic runs on background
        await delegate?.engineDidStartGenerating() // Calls main thread
        // ... logic ...
        await delegate?.engineDidFinishGenerating()
    }
}

// UI Wrapper (Main thread)
@MainActor
@Observable
final class GameViewModel: GameEngineDelegate {
    private let engine: LLMGameEngine
    var isGenerating: Bool = false

    func engineDidStartGenerating() {
        isGenerating = true
    }
}
```

### Phase 4: Play Testing Infrastructure
- [x] GameplayLogger - Capture gameplay data
- [x] AdventurePlayTest - Automated play test harness
- [ ] Wire up logging in LLMGameEngine
- [ ] Create test runner script

## Files Created
- [x] `Protocols/GameEngineDelegate.swift` - UI callback protocol
- [x] `Managers/GameplayLogger.swift` - Data collection
- [x] `Testing/AdventurePlayTest.swift` - Automated testing (won't compile until Phase 1-3 done)

## Files To Create
- [ ] `ViewModels/GameViewModel.swift` - UI state wrapper
- [ ] `ViewModels/CombatViewModel.swift` - Combat UI state
- [ ] `Scripts/run_playtests.swift` - Batch test runner

## Files To Modify
- [ ] `Protocols/GameEngine.swift` - Remove @MainActor
- [ ] `LLM/LLMGameEngine.swift` - Remove @Observable, add delegate
- [ ] `Managers/CombatManager.swift` - Remove @MainActor
- [ ] `Views/GameView.swift` - Use GameViewModel instead of LLMGameEngine
- [ ] `Views/ContentView.swift` - Create GameViewModel

## Breaking Changes
All views currently using `LLMGameEngine` directly will need to use `GameViewModel` wrapper instead.

## Migration Path
1. Complete Phase 1-3 (core refactoring)
2. Create GameViewModel with 1:1 property forwarding
3. Update views incrementally
4. Remove old properties from LLMGameEngine
5. Enable play testing infrastructure

## Expected Benefits
- Run 100+ adventures overnight for data collection
- Generate training datasets automatically
- Test narrative quality without UI
- Faster iteration on game balance
- Parallel test execution

## Risks
- Large refactoring across many files
- Views need significant updates
- May break existing functionality temporarily
- @Observable macro may not work without @MainActor

## Alternative: Minimal Change Approach
Instead of full refactoring, add async access layer:
```swift
// Keep @MainActor on LLMGameEngine
// Add test-friendly wrapper
actor GameEngineTestAdapter {
    private var engine: LLMGameEngine?

    @MainActor
    private func getEngine() -> LLMGameEngine {
        if engine == nil {
            engine = LLMGameEngine()
        }
        return engine!
    }

    func submitAction(_ input: String) async {
        await getEngine().submitPlayer(input: input)
    }
}
```

This allows testing without major refactoring, but limits parallelization.
