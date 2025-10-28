# DunGen Narrative Consistency & Quality Plan
_A compact, implementation-ready spec for improving consistency and prose quality while staying on-device and within the 8‑specialist architecture._

> **Scope.** This document consolidates the improvement brainstorm into an actionable plan: consistency contracts, structured memory, beat templates, a narrative linter, a one-pass FixIt loop, schema tweaks, context compression, variety controls, determinism boundaries, and offline tests.

---

## 1) Consistency Contract (CC)
A single ultra-compact line the whole system must honor every turn. Persist in Tier‑1 context so it survives resets.

```
CC: POV=2P Tense=Present Time=Dusk Wx=Fog Loc=Thornhaven
    Q=RetrieveAmulet QStage=MID STY=2
    Threads=[T12,T7] NPC=[N4:ally] Pending=[Boss?0]
```

**Rules**
- **Authoritative**: Any output that contradicts CC must be patched or rejected.
- **Stable keys**: `POV,Tense,Time,Wx,Loc,Q,QStage,STY,Threads,NPC,Pending` (add sparingly).
- **Rotation**: `STY=1..4` micro‑tones chosen code‑side (see §8).

**Usage**
- Inject CC into the top of each specialist’s prompt.
- The **Judge** checks CC adherence; the **FixIt** pass receives CC for correction.

---

## 2) Entity Cards & Open Threads
Use short, fixed-width “cards” instead of prose memories. Reference by IDs in prompts; expand to text only at render time.

```
PC: Kael L5 WARR HP45/45
LC: Thornhaven (smithy, market, gate) Mood:uneasy Time:dusk Wx:fog
Q : Retrieve Amulet → Camp N woods (Clue: CROW_TOTEM)
TH: T12 "crow totem" due≤3; T7 "old well rumor" due≤2
```

**Guidelines**
- Keep cards ≤80 chars each.
- **Open threads** carry a `due≤N` to enforce payoff windows (see §9 tests).
- Prompts pass only IDs (`T12`), not the full text—renderer expands at the end.

---

## 3) Beat Templates per Encounter
Quality scaffolding without bloat (2–5 sentences total, ≤85 words).

- **Exploration**: `Setting(1) → Discovery/Texture(1) → Hook/Complication(1) → Internal beat(0–1)`  
- **Social**: `Setting(1) → Motive reveal(1) → Tension(1) → Exit beat(0–1)` (dialogue capped to 2 turns)  
- **StoryBeat/Shop/Trap (narrative)**: follow the same skeleton; **ban** combat‑resolution verbs.

**Enforcement**
- ≥1 sensory detail.  
- ≤1 new proper noun per turn.  
- No grants/purchases in narrative; suggestions only (code decides).

---

## 4) Narrative Linter (deterministic, pre-sanitizer)
A fast post‑gen fixer before the existing combat‑verb sanitizer.

**Patch Rules**
1. **POV/Tense**: force 2nd‑person present (regex rules + minimal verb inflection table).
2. **Numbers → diegesis**: replace raw HP/XP/gold counts with world phrasing (“your breath steadies”).  
3. **Acquisition verbs**: “pick up/gain/find gold” → move to `suggestedActions`; clear `suggestedGrants` if code denies.  
4. **Time/Weather/Location drift**: align to CC if mismatched tokens appear.  
5. **Proper‑noun throttle**: if >1 new proper noun, downcase/genericize extras.

---

## 5) Judge → FixIt One‑Pass Loop
Only run FixIt when needed to preserve tokens.

**Gate**
```
if consistency < 0.85 or variety < 0.75: run FixIt(turnDiffSpec <= 120 chars) else: accept
```

**FixIt Diff Format (input to Adventure in FixIt mode)**
```
FIX: keep content; enforce dusk+fog; reference T12 once; remove filler; 3 sentences; ≤75 words.
```

**Expected Output**
- Same scene content, adjusted for CC and constraints—no new entities.

---

## 6) Schema Tweaks (surgical, backwards‑compatible)

### 6.1 AdventureTurn (additions)
```jsonc
{
  "tags": ["sens:smell","tone:uneasy","motif:crow"],
  "threadsUsed": ["T12"],
  "risks": ["npc_drift","time_jump","monster_mismatch"],
  "stageConfidence": 0.92,
  "suggestedActions": ["ask the peddler about the totem"],
  "suggestedGrants": [] // code decides; narrative never grants
}
```

### 6.2 NPCDefinition (additions)
```jsonc
{
  "lastTopic": "crow totem rumor",
  "promises": ["T7"]
}
```

---

## 7) Context Compression
**Codebook Lexicon (per biome/location)**
```
LX: { CROW_TOTEM="charred crow totem",
      SMELL_PINE="sharp resin of pine",
      LAMP_GLOW="wavering lamplight" }
```
Prompts use tokens (`CROW_TOTEM`); renderer expands on output.

**Delta Memories (MM+)**
```
MM+: LC.time=dusk; LC.wx=fog; Q.stage=MID→MID+; TH.use=T12
```
ContextBuilder reconstructs full cards on-device.

**Reset Rehydration (every ~15 turns)**
- Send: `CC + active cards + top 2 open threads + 1 chapter roll‑up line` (from Summarizer).

---

## 8) Determinism Boundaries & Micro‑Styles
- All randomness remains **code‑side**.
- Provide `STY=1..4` in CC; each toggles a lightweight diction preset:
  - `1 somber`, `2 brisk`, `3 wry`, `4 lyrical`  
- Specialists **do not roll** randomness; they react to `STY` only.

---

## 9) Variety Without Drift
- **Rhythm Manager**: enforce sentence length pattern across 4 turns: `short → medium → short → medium/long`.
- **Sensory Rotation**: prefer `sight → sound → smell → touch` hints to avoid repetition.
- **Reservoir Adjectives**: code‑side rotating pools per biome/class; renderer slots tokens (saves tokens and keeps style stable).

---

## 10) Offline Quality Tests (200‑turn simulation)
All checks run without model calls.

- **Entity Drift**: % turns violating CC (target **<1%**).
- **Thread Closure Rate**: % open threads resolved by due window (target **>80%**).
- **Verb Ban Fail Rate**: banned combat verbs *pre‑sanitizer* (trend to **0**).
- **Variety Score**: no 3 consecutive identical encounter beats/adjectives.
- **Quest Pace Score**: H → MID → FINAL with ≤3 “stall” turns per stage.

---

## 11) Prompt Skeletons (updated, compact)

### 11.1 AdventurePlanner (non‑combat only; 120–180t)
```
SYS: Honor CC. Non‑combat only. Use beat template. ≤3 bullets, ≤12 words each.
IN : {CC}{playerLite}{questState}{historyEnc}{trapGap}{last5Quests}{STY}
OUT: {"encounter":"social|exploration|trap|shop|story",
      "beats":["…","…","…"],
      "npcHints":["…"]}
```

### 11.2 ScenePainter (≤45 words)
```
SYS: 2 sentences. Sensory, compact. No combat verbs. Honor CC & beats.
IN : {CC}{beats}{LX}{STY}
OUT: plain text
```

### 11.3 DialogueSmith (≤80 words, max 2 turns unless referenced)
```
SYS: Brief, stakes-forward, 2 turns. If prior turn referenced, allow continuity.
OUT: "NPC: …\nYOU: …"
```

### 11.4 LoreKeeper
```
OUT: {"ok":true}|{"ok":false,"fix":["tense","time","wx","loc","name","propnoun_excess"]}
```

### 11.5 QuestWriter (per quest type)
```
OUT: "Objective: …" (≤16 words)\n"Progress: …" (≤16 words)
```

### 11.6 EncounterWeaver (3–5 sentences, ≤85 words)
```
SYS: Merge scene+dialogue+quest. No item grants. No combat verbs. Honor CC.
```

### 11.7 Summarizer (≤35 tokens)
```
OUT: "- S:{scene} N:{npc?} Q:{objective} F:{flags}"
```

### 11.8 Judge
```
OUT: {"consistency":0..1,"pacing":0..1,"variety":0..1,"notes":["…"]}
```

### 11.9 FixIt (only on gate fail)
```
IN: CC + OriginalOutput + Short FIX diff
OUT: Revised text; same content; constraints satisfied; no new entities.
```

---

## 12) Integrations & Hooks

- **Pre-Weave**: `LoreKeeper → Linter → Sanitizer`
- **Isolation**: While `inCombat == true`, UI blocks shop/equipment; narrative must not suggest purchases.
- **Regen**: Apply +1 HP after non‑damaging encounters when HP<max (code‑side).

---

## 13) Minimal Implementation Checklist
- [ ] Add CC to Tier‑1 context; thread through all prompts.
- [ ] Implement cards + open threads with `due≤N` and ID references.
- [ ] Add beat templates + enforcement checks.
- [ ] Implement Narrative Linter rules (regex + small tables).
- [ ] Add Judge gate + one‑pass FixIt mode.
- [ ] Extend schemas (`tags`, `threadsUsed`, `risks`, `stageConfidence`, `suggested*`).
- [ ] Add LX codebook + MM+ deltas + reset rehydration.
- [ ] Introduce `STY` tones; move all randomness to code.
- [ ] Add rhythm/sensory rotation + adjective reservoirs.
- [ ] Build offline tests; add to CI for 200‑turn sims.

---

## 14) Appendix: Reference Snippets

### 14.1 Combat‑Verb Sanitizer (example)
```swift
struct NarrativeSanitizer {
  private let banned = try! NSRegularExpression(
    pattern: #"\b(kill|slay|stab|shoot|strike|attack|maim|decapitat(e|es|ed|ing))\b"#,
    options: [.caseInsensitive]
  )
  func stripCombatVerbs(_ s: String) -> String {
    let r = NSMutableString(string: s)
    banned.replaceMatches(in: r, options: [], range: NSRange(location: 0, length: r.length), withTemplate: "—")
    return r as String
  }
}
```

### 14.2 FixIt Diff Examples
```
FIX: keep content; tense=present; remove noon→dusk; add 1 smell detail; 3 sentences.
FIX: keep content; reference T7 once; cut proper nouns to ≤1; ≤70 words.
```

### 14.3 Thread Ledger Examples
```
TH: T12 "crow totem" due≤3 (used=0)
TH: T7  "old well rumor" due≤2 (used=1)
```

---

**Outcome:** Tighter turns that keep promises, close loops on schedule, avoid drift, and read like authored prose—without growing prompt size or violating on‑device constraints.
