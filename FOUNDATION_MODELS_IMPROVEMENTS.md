# Foundation Models Framework Improvements

Based on analysis of Apple's Foundation Models documentation, this document outlines potential improvements to DunGen's LLM integration.

## Current Implementation Status

### ✅ Features Already Used
- `SystemLanguageModel.default` for on-device LLM
- `LanguageModelSession` with custom instructions per specialist
- Structured generation (`@Generable`, `@Guide`)
- Session context/transcript management
- Error handling for availability and guardrails
- Multi-turn conversation support

### 🎯 Missing Features (Opportunities)

## 1. GenerationOptions (HIGH PRIORITY)

### Current State
All LLM calls use default settings with no temperature or token control.

### Opportunity
Fine-tune creativity, consistency, and response length per specialist.

### Implementation

```swift
// In LLMGameEngine or SpecialistSessionManager
func getGenerationOptions(for specialist: LLMSpecialist) -> GenerationOptions {
    var options = GenerationOptions()

    switch specialist {
    case .adventure:
        options.temperature = 0.9        // Creative storytelling
        options.maxResponseTokens = 150  // 2-4 sentences + actions

    case .encounter:
        options.temperature = 0.6        // Balanced variety
        options.maxResponseTokens = 50   // Type + difficulty + brief description

    case .monsters, .npc:
        options.temperature = 0.5        // Consistent but varied
        options.maxResponseTokens = 80   // Name + stats + description

    case .equipment:
        options.temperature = 0.4        // Mechanical consistency
        options.maxResponseTokens = 60   // Name + stats

    case .world, .character:
        options.temperature = 0.8        // Creative world-building
        options.maxResponseTokens = 300  // One-time generation

    case .abilities, .spells, .prayers:
        options.temperature = 0.5        // Balanced mechanics + flavor
        options.maxResponseTokens = 100  // Name + effect + description
    }

    return options
}

// Usage
let options = getGenerationOptions(for: .adventure)
let response = try await session.respond(to: prompt, generating: AdventureTurn.self, options: options)
```

### Benefits
- **Enforced brevity**: maxResponseTokens prevents rambling
- **Quality control**: Lower temperature for mechanics, higher for narrative
- **Token efficiency**: Shorter responses = more turns before session reset
- **Consistent testing**: Can add seed for reproducible test scenarios

### Effort
- **Low**: Add helper function, update ~8 call sites
- **Testing**: Verify temperature changes improve quality

### Risk
- **Low**: Can easily revert to defaults if quality degrades

---

## 2. Streaming Responses (MEDIUM PRIORITY)

### Current State
All responses block with loading overlay until complete.

### Opportunity
Stream narrative text word-by-word for responsive feel.

### Implementation

```swift
// For narrative-only responses (no structured data)
func streamNarrative(prompt: String) async throws -> String {
    var fullText = ""

    for try await partial in session.streamResponse(to: prompt) {
        let newText = partial.content
        fullText += newText

        await MainActor.run {
            appendModel(newText)  // Update UI incrementally
        }
    }

    return fullText
}
```

### Challenges
- **Structured generation compatibility**: `@Generable` may not work with streaming
- **Partial JSON parsing**: Can't parse actions/rewards until complete
- **Error handling**: Need to handle mid-stream failures

### Hybrid Approach
1. Stream narrative text only
2. Block for structured fields (actions, rewards)
3. Parse complete response at end

### Benefits
- **Perceived performance**: 2-4 second waits feel instant
- **Traditional feel**: Text appearing word-by-word like classic adventures
- **Engagement**: Player starts reading immediately

### Effort
- **Medium**: Requires refactoring response handling
- **Testing**: Ensure structured data still parsed correctly

### Risk
- **Medium**: Could break structured generation if not handled carefully

---

## 3. Session Prewarming (LOW PRIORITY)

### Current State
Sessions initialized lazily on first use.

### Opportunity
Prewarm during character creation for faster first turn.

### Implementation

```swift
// During character creation screen (while player chooses race/class)
func prewarmSessions() async {
    await adventureSession.prewarm(promptPrefix: "You are in")
    await encounterSession.prewarm(promptPrefix: "Encounter:")
}
```

### Benefits
- **First turn 200-500ms faster**
- **Smoother gameplay start**
- **Better first impression**

### Trade-offs
- **Battery usage**: Prewarming consumes power during character creation
- **Marginal gain**: May not be noticeable on fast devices
- **Complexity**: Need to handle prewarm failures gracefully

### Effort
- **Low**: Single async call during character creation
- **Testing**: Measure first turn latency before/after

### Risk
- **Low**: Worst case is no improvement

---

## 4. Content Tagging / Specialized Models (NOT RECOMMENDED)

### Current State
Only using `SystemLanguageModel.default`.

### Investigated Opportunity
Apple's Foundation Models framework supports content tagging for categorizing data into themes (e.g., "Verbs," "Anatomy," "Difficult" in Vocabulary app).

### Potential Uses Considered
- **Player intent classification**: Categorize input as combat/social/exploration
- **Quest type detection**: Auto-classify quest goals
- **Sentiment detection**: Detect player frustration/confusion
- **Item/monster themes**: Categorize for variety tracking

### Decision: SKIP

**Reasons:**
1. **Current keyword matching works well** - No pain points to solve
2. **Unknown API availability** - Content tagging API not documented in FoundationModels framework
3. **Performance cost** - Each categorization = additional LLM call per turn
4. **Complexity vs. benefit** - Marginal accuracy improvement over deterministic keyword matching
5. **Debuggability** - Keyword matching easier to debug than LLM classification

### Better Alternative
Enhance existing keyword-based intent detection with more comprehensive keyword lists and scoring system (deterministic, fast, debuggable).

### Future Reconsideration
Revisit if:
- Content tagging API becomes documented and accessible
- We identify a specific pain point that keyword matching can't solve
- Performance characteristics prove acceptable

---

## Recommended Implementation Order

### Phase 1: Quick Wins (1-2 hours)
1. ✅ **Add GenerationOptions per specialist**
   - Low effort, immediate quality benefits
   - Can tune temperature based on playtesting
   - Enforces response length limits

### Phase 2: Quality Testing (2-3 days)
1. **Playtest with GenerationOptions**
   - Compare narrative quality at different temperatures
   - Measure token savings from maxResponseTokens
   - A/B test with players if possible

### Phase 3: Advanced Features (1-2 weeks)
1. **Evaluate streaming responses**
   - Prototype in isolated branch
   - Measure perceived performance improvement
   - Test structured generation compatibility

2. **Add prewarming**
   - Quick implementation
   - Measure first turn latency improvement
   - Monitor battery impact

### Phase 4: Research (Ongoing)
1. **Investigate specialized models**
   - Read Apple documentation
   - Test available models
   - Evaluate fit for DunGen

---

## Success Metrics

### GenerationOptions
- [ ] Narrative feels more creative/varied
- [ ] Mechanics feel more consistent
- [ ] Response length stays within limits
- [ ] Token usage reduced by 10-20%

### Streaming
- [ ] Perceived latency reduced by 50%+
- [ ] No loss of structured data quality
- [ ] Players report more engaging experience

### Prewarming
- [ ] First turn 200-500ms faster
- [ ] No noticeable battery drain during character creation

---

## Notes

- **Temperature range**: 0.0 (deterministic) to 2.0 (very creative)
  - 0.3-0.5: Mechanics, stats, consistent data
  - 0.6-0.8: Balanced creativity
  - 0.9-1.2: Narrative, storytelling

- **maxResponseTokens**: Actual token count, not character count
  - ~100 tokens = 2-4 sentences
  - Set conservatively to prevent overflow

- **Seed parameter**: Use in integration tests for reproducibility
  - Fixed seed = deterministic outputs
  - Easier to write regression tests
