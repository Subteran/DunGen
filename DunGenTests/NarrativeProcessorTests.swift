import Testing
import Foundation
@testable import DunGen

struct NarrativeProcessorTests {

    @Test("Sanitize narration preserves narrative text for combat encounters")
    func testSanitizeNarrationCombat() {
        let processor = NarrativeProcessor()
        let text = "You defeated the goblin and killed it."
        let sanitized = processor.sanitizeNarration(text, for: "combat")

        #expect(sanitized.contains("defeated"))
        #expect(sanitized.contains("killed"))
        #expect(sanitized == text)
    }

    @Test("Sanitize narration preserves narrative text for final encounters")
    func testSanitizeNarrationFinal() {
        let processor = NarrativeProcessor()
        let text = "You struck the dragon with your sword."
        let sanitized = processor.sanitizeNarration(text, for: "final")

        #expect(sanitized.contains("struck"))
        #expect(sanitized == text)
    }

    @Test("Sanitize narration preserves text for non-combat encounters")
    func testSanitizeNarrationNonCombat() {
        let processor = NarrativeProcessor()
        let text = "You defeated the puzzle and killed the trap."
        let sanitized = processor.sanitizeNarration(text, for: "exploration")

        #expect(sanitized == text)
    }

    @Test("Sanitize narration removes spurious JSON characters")
    func testSanitizeNarrationRemovesJSON() {
        let processor = NarrativeProcessor()
        let text = "You defeated the enemy.\n{\n\"narration\": \"extra text\""
        let sanitized = processor.sanitizeNarration(text, for: "combat")

        #expect(sanitized.contains("{") == false)
        #expect(sanitized.contains("\"narration\"") == false)
        #expect(sanitized.contains("defeated"))
    }

    @Test("Smart truncate preserves prompt under max length")
    func testSmartTruncateUnderMaxLength() {
        let processor = NarrativeProcessor()
        let prompt = "Short prompt"
        let truncated = processor.smartTruncatePrompt(prompt, maxLength: 100)

        #expect(truncated == prompt)
    }

    @Test("Smart truncate preserves warning emoji lines")
    func testSmartTruncatePreservesWarnings() {
        let processor = NarrativeProcessor()
        let prompt = """
        Some random text
        ⚠ This must be kept
        More random text
        Another line
        """
        let truncated = processor.smartTruncatePrompt(prompt, maxLength: 50)

        #expect(truncated.contains("⚠"))
    }

    @Test("Smart truncate preserves quest stage lines")
    func testSmartTruncatePreservesQuestStage() {
        let processor = NarrativeProcessor()
        let prompt = """
        Random text
        STAGE-EARLY: Important info
        More text
        """
        let truncated = processor.smartTruncatePrompt(prompt, maxLength: 60)

        #expect(truncated.contains("STAGE-"))
    }

    @Test("Smart truncate preserves short quest lines")
    func testSmartTruncatePreservesShortQuestLines() {
        let processor = NarrativeProcessor()
        let prompt = """
        Random text
        quest: Find the artifact
        More text
        """
        let truncated = processor.smartTruncatePrompt(prompt, maxLength: 50)

        #expect(truncated.contains("quest:"))
    }

    @Test("Smart truncate handles very long prompts")
    func testSmartTruncateVeryLongPrompt() {
        let processor = NarrativeProcessor()
        let prompt = String(repeating: "a", count: 2000)
        let truncated = processor.smartTruncatePrompt(prompt, maxLength: 500)

        #expect(truncated.count <= 500)
    }

    @Test("Extract keywords finds action verbs")
    func testExtractKeywordsActionVerbs() {
        let processor = NarrativeProcessor()
        let text = "I attack the goblin with my sword"
        let keywords = processor.extractKeywords(from: text, isPlayerAction: true)

        #expect(keywords.contains("attack"))
    }

    @Test("Extract keywords finds entities")
    func testExtractKeywordsEntities() {
        let processor = NarrativeProcessor()
        let text = "I see a dragon and a chest"
        let keywords = processor.extractKeywords(from: text, isPlayerAction: true)

        #expect(keywords.contains("dragon") || keywords.contains("chest"))
    }

    @Test("Extract keywords finds outcomes for non-player actions")
    func testExtractKeywordsOutcomes() {
        let processor = NarrativeProcessor()
        let text = "The hero defeated the monster and gained experience"
        let keywords = processor.extractKeywords(from: text, isPlayerAction: false)

        #expect(keywords.contains("defeated") || keywords.contains("gained"))
    }

    @Test("Extract keywords limits to 3 keywords")
    func testExtractKeywordsLimit() {
        let processor = NarrativeProcessor()
        let text = "I attack the goblin in the room with a sword and found a chest"
        let keywords = processor.extractKeywords(from: text, isPlayerAction: true)
        let keywordCount = keywords.split(separator: " ").count

        #expect(keywordCount <= 3)
    }

    @Test("Extract keywords is case insensitive")
    func testExtractKeywordsCaseInsensitive() {
        let processor = NarrativeProcessor()
        let text = "I ATTACK the DRAGON"
        let keywords = processor.extractKeywords(from: text, isPlayerAction: true)

        #expect(keywords.lowercased().contains("attack") || keywords.lowercased().contains("dragon"))
    }

    @Test("Generate encounter summary with monster")
    func testGenerateEncounterSummaryWithMonster() {
        let processor = NarrativeProcessor()
        let monster = MonsterDefinition(
            baseName: "Goblin",
            prefix: nil,
            suffix: nil,
            hp: 10,
            damage: "1d6+2",
            defense: 2,
            abilities: [],
            description: "A small green creature"
        )

        let summary = processor.generateEncounterSummary(
            narrative: "You encounter a goblin",
            encounterType: "combat",
            monster: monster,
            npc: nil
        )

        #expect(summary.contains("fight"))
        #expect(summary.contains("Goblin"))
    }

    @Test("Generate encounter summary with NPC")
    func testGenerateEncounterSummaryWithNPC() {
        let processor = NarrativeProcessor()
        let npc = NPCDefinition(
            name: "Merchant",
            occupation: "Trader",
            appearance: "Well dressed",
            personality: "Friendly",
            location: "Market",
            backstory: "Sells items",
            relationshipStatus: "friendly",
            interactionCount: 0
        )

        let summary = processor.generateEncounterSummary(
            narrative: "You meet a merchant",
            encounterType: "social",
            monster: nil,
            npc: npc
        )

        #expect(summary.contains("meet"))
        #expect(summary.contains("Merchant"))
    }

    @Test("Generate encounter summary from narrative keywords")
    func testGenerateEncounterSummaryFromKeywords() {
        let processor = NarrativeProcessor()

        let summary = processor.generateEncounterSummary(
            narrative: "You search the room and find a chest",
            encounterType: "exploration",
            monster: nil,
            npc: nil
        )

        #expect(summary.contains("search") || summary.contains("chest"))
    }

    @Test("Generate encounter summary limits to 60 characters")
    func testGenerateEncounterSummaryLimitLength() {
        let processor = NarrativeProcessor()
        let monster = MonsterDefinition(
            baseName: String(repeating: "VeryLongMonsterName", count: 10),
            prefix: nil,
            suffix: nil,
            hp: 10,
            damage: "1d6+2",
            defense: 2,
            abilities: [],
            description: "Long description"
        )

        let summary = processor.generateEncounterSummary(
            narrative: "Long narrative",
            encounterType: "combat",
            monster: monster,
            npc: nil
        )

        #expect(summary.count <= 60)
    }

    @Test("Generate encounter summary falls back to encounter type")
    func testGenerateEncounterSummaryFallbackToType() {
        let processor = NarrativeProcessor()

        let summary = processor.generateEncounterSummary(
            narrative: "Plain text with no keywords",
            encounterType: "puzzle",
            monster: nil,
            npc: nil
        )

        #expect(summary == "puzzle")
    }

    @Test("Smart truncate preserves location lines")
    func testSmartTruncatePreservesLocation() {
        let processor = NarrativeProcessor()
        let prompt = """
        Random text
        location: Dark Forest
        More text
        """
        let truncated = processor.smartTruncatePrompt(prompt, maxLength: 50)

        #expect(truncated.contains("location:"))
    }

    @Test("Smart truncate preserves encounter lines")
    func testSmartTruncatePreservesEncounter() {
        let processor = NarrativeProcessor()
        let prompt = """
        Random text
        encounter: combat (hard)
        More text
        """
        let truncated = processor.smartTruncatePrompt(prompt, maxLength: 50)

        #expect(truncated.contains("encounter:"))
    }
}
