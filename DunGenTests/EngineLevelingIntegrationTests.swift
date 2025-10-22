import Testing
@testable import DunGen

@MainActor
@Suite("Engine Leveling Integration Tests")
struct EngineLevelingIntegrationTests {

    @Test("Engine appends level-up log when XP crosses threshold")
    func engineAppendsLevelUpLog() async throws {
        // GIVEN an engine with a character near level 2 (threshold at 150 XP)
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.character = CharacterProfile(
            name: "Test Hero",
            race: "Elf",
            className: "Ranger",
            backstory: "A swift scout from the greenwood.",
            attributes: .init(strength: 10, dexterity: 14, constitution: 12, intelligence: 12, wisdom: 13, charisma: 9),
            hp: 11, maxHP: 11, xp: 140, gold: 10, inventory: [],
            abilities: ["Track"],
            spells: []
        )

        // WHEN a turn arrives that grants enough XP to level up
        let turn = AdventureTurn(
            narration: "You best a rival and learn from the duel.",
            adventureProgress: nil,
            playerPrompt: "What do you do next?",
            suggestedActions: ["Continue exploring", "Rest"],
            currentEnvironment: "Training Grounds"
        )

        let rewards = ProgressionRewards(
            xpGain: 10,
            hpDelta: 0,
            goldGain: 0,
            shouldDropLoot: false,
            itemDropCount: 0
        )

        // Process the turn without invoking the LLM
        await engine.apply(turn: turn, encounter: nil, rewards: rewards, loot: [], monster: nil, npc: nil)

        // THEN the character's XP is updated and a level-up log appears
        let c = try #require(engine.character)
        #expect(c.xp == 150)
        #expect(c.maxHP > 11)
        #expect(c.hp == c.maxHP)
        let hasLevelUpLine = engine.log.contains { $0.isFromModel && $0.content.contains("Level ") }
        #expect(hasLevelUpLine)
    }
}
