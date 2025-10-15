import Testing
@testable import DunGen

@MainActor
@Suite("Engine Leveling Integration Tests")
struct EngineLevelingIntegrationTests {

    @Test("Engine appends level-up log when XP crosses threshold")
    func engineAppendsLevelUpLog() async throws {
        // GIVEN an engine with a character near level 2
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.character = CharacterProfile(
            name: "Test Hero",
            race: "Elf",
            className: "Ranger",
            backstory: "A swift scout from the greenwood.",
            attributes: .init(strength: 10, dexterity: 14, constitution: 12, intelligence: 12, wisdom: 13, charisma: 9),
            hp: 11, xp: 95, gold: 10, inventory: [],
            abilities: ["Track"],
            spells: []
        )

        // WHEN a turn arrives that grants enough XP to level up
        let turn = AdventureTurn(
            narration: "You best a rival and learn from the duel.",
            playerPrompt: "",
            nextLocationType: nil,
            summaryStats: .init(hp: 11, xp: 100, gold: 10),
            progression: .init(xpGain: 10, hpDelta: nil, inventoryChanges: nil)
        )

        // Process the turn without invoking the LLM
        engine.apply(turn: turn)

        // THEN the character's XP is updated and a level-up log appears
        let c = try #require(engine.character)
        #expect(c.xp == 105)
        #expect(c.hp > 11)
        let hasLevelUpLine = engine.log.contains { $0.isFromModel && $0.content.contains("Level ") }
        #expect(hasLevelUpLine)
    }
}
